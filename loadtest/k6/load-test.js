// Prueba de carga de Universe Social Network con k6.
//
// Simula usuarios reales a través del balanceador (nginx → servicios):
// abren la web, inician sesión, leen posts y su línea de tiempo, publican y
// analizan texto con el servicio de IA. El login (BCrypt + JWT) es la operación
// más costosa en CPU, por lo que la carga hace escalar el backend con el HPA.
//
// Variables de entorno:
//   BASE_URL  URL de la aplicación (obligatoria), p. ej. http://xxxx.elb.amazonaws.com
//   MAX_VUS   usuarios virtuales en el pico (por defecto 60)
//   HOLD      duración del pico (por defecto 4m)
//   USERS     cuentas de prueba creadas al inicio (por defecto 20)

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Counter } from 'k6/metrics';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';

const BASE_URL = (__ENV.BASE_URL || '').replace(/\/$/, '');
const MAX_VUS = parseInt(__ENV.MAX_VUS || '60', 10);
const HOLD = __ENV.HOLD || '4m';
const USERS = parseInt(__ENV.USERS || '20', 10);
const PASSWORD = 'Carga-k6-2026!';
const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

const businessErrors = new Counter('business_errors');

export const options = {
  // Rampa: subida gradual, pico sostenido y bajada (para observar el
  // escalamiento y luego la reducción de réplicas).
  stages: [
    { duration: '1m', target: Math.ceil(MAX_VUS / 3) },
    { duration: '2m', target: MAX_VUS },
    { duration: HOLD, target: MAX_VUS },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'],              // menos de 5 % de errores
    'http_req_duration{group:::Login}': ['p(95)<3000'],
    'http_req_duration{group:::Leer}': ['p(95)<2000'],
    checks: ['rate>0.95'],
  },
  setupTimeout: '2m',
};

export function setup() {
  if (!BASE_URL) {
    throw new Error('Definir BASE_URL, por ejemplo: -e BASE_URL=http://xxxx.elb.amazonaws.com');
  }
  const ready = http.get(`${BASE_URL}/api/actuator/health/readiness`);
  if (ready.status !== 200) {
    throw new Error(`La aplicación no está lista: ${ready.status}`);
  }

  // Crea las cuentas de prueba (nombres únicos por ejecución).
  const run = Date.now().toString(36);
  const users = [];
  for (let i = 0; i < USERS; i++) {
    const username = `k6_${run}_${i}`;
    const res = http.post(`${BASE_URL}/api/auth/register`, JSON.stringify({
      username, password: PASSWORD, firstname: 'Carga', lastname: `k6 ${i}`, country: 'Peru',
    }), JSON_HEADERS);
    if (res.status === 200) {
      users.push({ username, id: res.json('id') });
    }
  }
  if (users.length === 0) {
    throw new Error('No se pudo registrar ningún usuario de prueba');
  }
  console.log(`Usuarios de prueba creados: ${users.length}`);
  return { users };
}

export default function (data) {
  const user = data.users[(__VU + __ITER) % data.users.length];

  group('Web', () => {
    const res = http.get(`${BASE_URL}/`, { tags: { name: 'GET /' } });
    check(res, { 'web 200': (r) => r.status === 200 });
  });

  group('Login', () => {
    const res = http.post(`${BASE_URL}/api/auth/login`,
      JSON.stringify({ username: user.username, password: PASSWORD }),
      Object.assign({ tags: { name: 'POST /api/auth/login' } }, JSON_HEADERS));
    const ok = check(res, {
      'login 200': (r) => r.status === 200,
      'login devuelve token': (r) => r.status === 200 && !!r.json('token'),
    });
    if (!ok) businessErrors.add(1);
  });

  group('Leer', () => {
    const timeline = http.get(`${BASE_URL}/api/posts/${user.id}/timeline`,
      { tags: { name: 'GET /api/posts/{id}/timeline' } });
    check(timeline, { 'timeline 200': (r) => r.status === 200 });

    const profile = http.get(`${BASE_URL}/api/user/${user.id}`, { tags: { name: 'GET /api/user/{id}' } });
    check(profile, { 'perfil 200': (r) => r.status === 200 });
  });

  // 1 de cada 10 iteraciones publica un post.
  if (Math.random() < 0.1) {
    group('Publicar', () => {
      const res = http.post(`${BASE_URL}/api/posts`,
        JSON.stringify({ userId: user.id, desc: `Post de carga k6 VU ${__VU} iteración ${__ITER}` }),
        Object.assign({ tags: { name: 'POST /api/posts' } }, JSON_HEADERS));
      check(res, { 'post creado': (r) => r.status === 200 || r.status === 201 });
    });
  }

  // 3 de cada 10 iteraciones analizan texto con el servicio de IA.
  if (Math.random() < 0.3) {
    group('IA', () => {
      const res = http.post(`${BASE_URL}/ai/analyze`,
        JSON.stringify({ text: 'Excelente clase de cloud computing con mis amigos #UNSA' }),
        Object.assign({ tags: { name: 'POST /ai/analyze' } }, JSON_HEADERS));
      check(res, { 'ia 200': (r) => r.status === 200 });
    });
  }

  sleep(1);
}

export function handleSummary(data) {
  return {
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
    'results/summary.json': JSON.stringify(data, null, 2),
  };
}
