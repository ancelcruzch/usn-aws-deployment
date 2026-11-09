package com.unsa.backend.apptest;

import static org.junit.jupiter.api.Assertions.assertNotNull;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import com.unsa.backend.BackendApplication;

@SpringBootTest
@DisplayName("Backend Application Test")
class BackendApplicationTest {
    
    /*
     * Verifica que la aplicación se cargue correctamente
    */ 
    @Test
    void contextLoads() {
        // Puerto aleatorio: evita conflictos con otro proceso en el puerto 5000.
        BackendApplication.main(new String[]{"--server.port=0"});
        assertNotNull(BackendApplication.class);
    }
}
