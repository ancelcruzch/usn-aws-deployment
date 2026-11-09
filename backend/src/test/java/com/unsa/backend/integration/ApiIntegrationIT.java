package com.unsa.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;

/**
 * Pruebas de integración: levantan la aplicación completa (servidor HTTP,
 * seguridad, servicios, JPA) contra una base MySQL 8.0 real creada por
 * Testcontainers (perfil "test"). Verifican flujos de punta a punta a través
 * de la API REST, tal como los usa el frontend.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@DisplayName("API REST - integración con MySQL")
class ApiIntegrationIT {

    private static final ParameterizedTypeReference<Map<String, Object>> MAP =
            new ParameterizedTypeReference<>() { };
    private static final ParameterizedTypeReference<List<Map<String, Object>>> LIST =
            new ParameterizedTypeReference<>() { };

    @Autowired
    private TestRestTemplate http;

    /** Registra un usuario con nombre único y devuelve la respuesta (token, id...). */
    private Map<String, Object> register(String password) {
        String username = "it_" + UUID.randomUUID().toString().substring(0, 8);
        ResponseEntity<Map<String, Object>> response = http.exchange("/auth/register", HttpMethod.POST,
                new HttpEntity<>(Map.of(
                        "username", username,
                        "password", password,
                        "firstname", "Integration",
                        "lastname", "Test",
                        "country", "Peru")),
                MAP);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private long createPost(long userId, String description) {
        ResponseEntity<Map<String, Object>> response = http.exchange("/posts", HttpMethod.POST,
                new HttpEntity<>(Map.of("userId", userId, "desc", description)), MAP);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        return ((Number) response.getBody().get("id")).longValue();
    }

    @Test
    @DisplayName("Health: la aplicación está viva y lista (incluye la conexión a MySQL)")
    void healthProbesAreUp() {
        ResponseEntity<Map<String, Object>> liveness =
                http.exchange("/actuator/health/liveness", HttpMethod.GET, null, MAP);
        ResponseEntity<Map<String, Object>> readiness =
                http.exchange("/actuator/health/readiness", HttpMethod.GET, null, MAP);

        assertThat(liveness.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(liveness.getBody()).containsEntry("status", "UP");
        assertThat(readiness.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readiness.getBody()).containsEntry("status", "UP");
    }

    @Test
    @DisplayName("Auth: registro e inicio de sesión devuelven un token JWT")
    void registerThenLogin() {
        Map<String, Object> user = register("Clave-Segura-123");
        String username = (String) user.get("username");

        assertThat(user.get("token")).asString().isNotBlank();
        assertThat(user.get("id")).isNotNull();

        ResponseEntity<Map<String, Object>> login = http.exchange("/auth/login", HttpMethod.POST,
                new HttpEntity<>(Map.of("username", username, "password", "Clave-Segura-123")), MAP);

        assertThat(login.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(login.getBody().get("token")).asString().isNotBlank();
        assertThat(login.getBody()).containsEntry("username", username);
    }

    @Test
    @DisplayName("Auth: una contraseña incorrecta es rechazada")
    void loginWithWrongPasswordIsRejected() {
        Map<String, Object> user = register("Clave-Segura-123");

        ResponseEntity<String> login = http.postForEntity("/auth/login",
                Map.of("username", user.get("username"), "password", "incorrecta"), String.class);

        assertThat(login.getStatusCode().is2xxSuccessful()).isFalse();
    }

    @Test
    @DisplayName("Posts: crear, consultar, dar like y aparecer en la línea de tiempo")
    void postLifecycle() {
        Map<String, Object> user = register("Clave-Segura-123");
        long userId = ((Number) user.get("id")).longValue();

        long postId = createPost(userId, "Primer post de integración");

        // Se persiste y se puede leer.
        ResponseEntity<Map<String, Object>> post =
                http.exchange("/posts/" + postId, HttpMethod.GET, null, MAP);
        assertThat(post.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(post.getBody()).containsEntry("desc", "Primer post de integración");

        // Like: se guarda el id del usuario en la lista de likes.
        ResponseEntity<String> like = http.exchange("/posts/" + postId + "/like", HttpMethod.PUT,
                new HttpEntity<>(Map.of("userId", userId)), String.class);
        assertThat(like.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Map<String, Object>> liked =
                http.exchange("/posts/" + postId, HttpMethod.GET, null, MAP);
        assertThat((List<?>) liked.getBody().get("likes"))
                .extracting(id -> ((Number) id).longValue())
                .contains(userId);

        // Aparece en la línea de tiempo del autor.
        ResponseEntity<List<Map<String, Object>>> timeline =
                http.exchange("/posts/" + userId + "/timeline", HttpMethod.GET, null, LIST);
        assertThat(timeline.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(timeline.getBody())
                .extracting(p -> ((Number) p.get("id")).longValue())
                .contains(postId);
    }

    @Test
    @DisplayName("Posts: eliminar un post lo quita de la base de datos")
    void deletePost() {
        Map<String, Object> user = register("Clave-Segura-123");
        long postId = createPost(((Number) user.get("id")).longValue(), "Post temporal");

        ResponseEntity<String> deleted =
                http.exchange("/posts/" + postId, HttpMethod.DELETE, null, String.class);
        assertThat(deleted.getStatusCode().is2xxSuccessful()).isTrue();

        ResponseEntity<String> afterDelete = http.getForEntity("/posts/" + postId, String.class);
        assertThat(afterDelete.getStatusCode().is2xxSuccessful()).isFalse();
    }

    @Test
    @DisplayName("Seguridad: un endpoint protegido exige autenticación")
    void protectedEndpointRequiresAuthentication() {
        ResponseEntity<String> response = http.getForEntity("/actuator/info", String.class);

        assertThat(response.getStatusCode().value()).isIn(401, 403);
    }
}
