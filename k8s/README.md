# Universe Social Network en EKS

Manifests para `usn-cluster`, namespace `usn`, sin frontend ni exposición pública.
Todos los Services son `ClusterIP`. MySQL usa un Service headless para su
StatefulSet de una réplica; el PVC independiente `mysql-data` conserva sus datos.
No escalar este StatefulSet por encima de una réplica: usa un único volumen.

## Antes de aplicar

1. Seleccionar el contexto Kubernetes de `usn-cluster` y comprobar que el nodo
   está `Ready`.
2. Tener instalado el add-on Amazon EBS CSI (`ebs.csi.aws.com`) con permisos IAM
   para aprovisionar volúmenes. El manifiesto StorageClass no instala el driver.
3. El rol IAM de los nodos debe poder descargar las imágenes de ECR indicadas.
4. Reemplazar los dos valores `REPLACE_WITH_*` de `mysql/01-secret.yaml` por
   contraseñas diferentes. No subir las contraseñas reales al repositorio.

MySQL inicializa la base `railway` y el usuario `usn` en un volumen vacío.
El backend toma usuario y contraseña del mismo Secret y usa DNS Kubernetes.
Cambiar el Secret posteriormente no cambia automáticamente las contraseñas de
una base ya inicializada; esa rotación requiere actualizar también MySQL.

## Orden de aplicación

Desde la raíz del repositorio, ejecutar manualmente:

```bash
kubectl config current-context
kubectl get nodes
kubectl get csidriver ebs.csi.aws.com

kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-storage-class.yaml
kubectl apply -f k8s/mysql/01-secret.yaml
kubectl apply -f k8s/mysql/02-pvc.yaml
kubectl apply -f k8s/mysql/03-service.yaml
kubectl apply -f k8s/mysql/04-statefulset.yaml
kubectl -n usn rollout status statefulset/mysql --timeout=300s

kubectl apply -f k8s/backend/
kubectl apply -f k8s/socket/
kubectl apply -f k8s/ai-service/

kubectl -n usn rollout status deployment/backend --timeout=300s
kubectl -n usn rollout status deployment/socket --timeout=300s
kubectl -n usn rollout status deployment/ai-service --timeout=300s
kubectl -n usn get pods,services,pvc
```

El PVC puede quedar `Pending` hasta crear el Pod MySQL porque la StorageClass
usa `WaitForFirstConsumer`. La política `Retain` conserva el volumen EBS si se
elimina el PVC; ese volumen sigue generando costos hasta su eliminación manual.

## DNS internos

| Service | DNS | Puerto |
| --- | --- | --- |
| mysql | mysql.usn.svc.cluster.local | 3306 |
| backend | backend.usn.svc.cluster.local | 5000 |
| socket | socket.usn.svc.cluster.local | 8800 |
| ai-service | ai-service.usn.svc.cluster.local | 8000 |

Estos nombres son internos al cluster. Para probar el backend desde la Mac:

```bash
kubectl -n usn port-forward service/backend 5001:5000
```

Los probes de MySQL usan loopback dentro del propio contenedor para comprobar
su base de datos; la conexión del backend utiliza exclusivamente el DNS del Service.

Referencia: [EBS CSI en EKS](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html).
