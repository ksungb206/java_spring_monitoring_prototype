package kr.co.mainapi;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import kr.co.mainapi.monitoring.MonitoringProperties;

@SpringBootApplication
@EnableScheduling
@EnableConfigurationProperties(MonitoringProperties.class)
public class MainApiApplication {
    public static void main(String[] args) {
        SpringApplication.run(MainApiApplication.class, args);
    }
}
