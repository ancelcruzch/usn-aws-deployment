package com.unsa.backend.config;

import java.util.HashMap;
import java.util.Map;

import com.cloudinary.Cloudinary;

import io.github.cdimascio.dotenv.Dotenv;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class CloudinaryConfig {

    // Las credenciales se leen de variables de entorno (Kubernetes Secret en EKS)
    // o, en desarrollo local, de un archivo .env opcional. Nunca se versionan.
    private static final Dotenv ENV = Dotenv.configure().ignoreIfMissing().load();

    public static final String CLOUD_NAME = ENV.get("CLOUDINARY_CLOUD_NAME", "");
    public static final String API_KEY = ENV.get("CLOUDINARY_API_KEY", "");
    private static final String API_SECRET = ENV.get("CLOUDINARY_API_SECRET", "");

    @Bean
    public Cloudinary cloudinary() {
        Map<String, String> config = new HashMap<>();
        config.put("cloud_name", CLOUD_NAME);
        config.put("api_key", API_KEY);
        config.put("api_secret", API_SECRET);
        return new Cloudinary(config);
    }
}
