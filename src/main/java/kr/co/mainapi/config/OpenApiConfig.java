package kr.co.mainapi.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {
    @Bean
    public OpenAPI mainApiOpenAPI() {
        return new OpenAPI().info(new Info()
                .title("MSA Monitoring API")
                .version("0.1.0")
                .description("Spring Boot MSA monitoring prototype API documentation"));
    }
}
