# Prueba de carga y autoscaling

Prueba de carga con **k6** contra la aplicación desplegada en EKS para
demostrar el **Horizontal Pod Autoscaler** (HPA) y analizar su comportamiento.

| Archivo | Uso |
| --- | --- |
| `k6/load-test.js` | Escenario de carga (usuarios virtuales) |
| `watch-hpa.ps1` | Registra réplicas y CPU de los HPA cada 10 s en un CSV |
| `../.github/workflows/load-test.yml` | Ejecuta la prueba desde GitHub Actions |
| `results/` | Resultados locales (ignorados por Git) |

## Escenario

Cada usuario virtual (VU) repite, con 1 s de pausa:

| Paso | Petición | Servicio |
| --- | --- | --- |
| Web | `GET /` | nginx (frontend) |
| Login | `POST /api/auth/login` | backend: BCrypt + JWT (**operación más costosa en CPU**) |
| Leer | `GET /api/posts/{id}/timeline`, `GET /api/user/{id}` | backend + RDS |
| Publicar (10 %) | `POST /api/posts` | backend + RDS |
| IA (30 %) | `POST /ai/analyze` | ai-service |

Carga (por defecto, unos 8 minutos):

```text
VUs
 60 |          ┌────────────────────┐
 20 |    ┌─────┘                    │
  0 |────┘                          └────
      1 min  2 min      4 min       1 min
```

Umbrales (la prueba falla si no se cumplen): errores HTTP < 5 %, p95 de login
< 3 s, p95 de lectura < 2 s y checks correctos > 95 %.

## Configuración del HPA que se evalúa

| Deployment | Mín. | Máx. | Métrica | Comportamiento |
| --- | --- | --- | --- | --- |
| backend | 2 | 6 | CPU 60 % de `requests` (250m) | Sube hasta el doble cada 30 s; baja 1 pod/min tras 2 min estable |
| frontend | 2 | 4 | CPU 70 % de `requests` (50m) | Baja tras 2 min estable |
| ai-service | 1 | 3 | CPU 70 % de `requests` (100m) | Baja tras 2 min estable |

## Ejecución

Requisitos: capa `platform` creada, aplicación desplegada por el CD, kubectl
configurado (`aws eks update-kubeconfig --region us-east-2 --name usn-cluster`)
y Docker Desktop (para k6).

**Terminal 1: registrar el autoscaling** (desde la raíz del repositorio)

```powershell
.\loadtest\watch-hpa.ps1
```

**Terminal 2: ver los pods en vivo**

```powershell
kubectl -n usn get hpa -w
```

**Terminal 3: ejecutar la prueba**

```powershell
$url = "http://" + (kubectl -n usn get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
docker run --rm -v "${PWD}/loadtest:/work" -w /work `
  -e BASE_URL=$url -e MAX_VUS=60 -e HOLD=4m `
  -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=results/k6-report.html `
  -p 5665:5665 grafana/k6 run k6/load-test.js
```

Mientras corre, **<http://localhost:5665>** muestra el panel en vivo de k6
(peticiones por segundo, latencia y errores).

Después, esperar unos 5 minutos con el registro activo para observar la
**reducción** de réplicas y detener `watch-hpa.ps1` con Ctrl+C.

**Alternativa sin Docker local:** GitHub → *Actions → Load test → Run
workflow*. El reporte HTML queda como artifact y el estado del HPA en el
resumen de la ejecución.

## Qué observar y capturar

| Evidencia | Dónde |
| --- | --- |
| Réplicas del backend 2 → hasta 6 y luego de vuelta a 2 | Terminal 2 y CSV de `watch-hpa.ps1` |
| Gráfico de réplicas y CPU en el tiempo | Excel con el CSV de `results/` |
| Peticiones/s, latencias p95 y errores | `results/k6-report.html` y resumen de k6 |
| CPU y memoria de pods y nodos, pods en ejecución | Dashboard `usn-cluster-overview` de CloudWatch |
| Eventos de escalado | `kubectl -n usn describe hpa backend` (sección *Events*) |
| Logs de errores durante la carga | Widget de errores del dashboard / CloudWatch Logs Insights |

## Comportamiento esperado (para el análisis)

1. **Subida (minutos 1-3)**: el login con BCrypt eleva la CPU del backend por
   encima del 60 % de lo solicitado. metrics-server reporta la métrica cada
   unos 15 s y el HPA crea réplicas nuevas (hasta duplicarlas cada 30 s).
2. **Arranque de réplicas**: cada pod nuevo tarda aproximadamente 1 minuto en
   pasar la readinessProbe (arranque de Spring Boot + conexión a RDS); hasta
   entonces no recibe tráfico, por lo que la latencia puede subir brevemente.
3. **Estabilización (pico)**: con más réplicas, la CPU media baja hacia el
   objetivo y la latencia se estabiliza.
4. **Bajada**: al terminar la carga, el HPA espera 2 minutos de estabilidad y
   retira 1 réplica por minuto hasta volver a 2.
5. **Límite de capacidad**: si las réplicas no caben en los 2 nodos, quedan
   en `Pending` (el Cluster Autoscaler está fuera del alcance del proyecto).
