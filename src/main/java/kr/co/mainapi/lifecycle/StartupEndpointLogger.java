package kr.co.mainapi.lifecycle;

import java.net.Inet4Address;
import java.net.NetworkInterface;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
public class StartupEndpointLogger {
    private static final Logger log = LoggerFactory.getLogger(StartupEndpointLogger.class);
    private final Environment environment;

    public StartupEndpointLogger(Environment environment) {
        this.environment = environment;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        String profile = String.join(",", environment.getActiveProfiles());
        if (profile.isBlank()) profile = "default";
        String port = environment.getProperty("local.server.port",
                environment.getProperty("server.port", "8080"));
        String bindAddress = environment.getProperty("server.address", "0.0.0.0");
        Set<String> addresses = new LinkedHashSet<>();
        if (!"0.0.0.0".equals(bindAddress) && !"::".equals(bindAddress)) {
            addresses.add(bindAddress);
        } else {
            try {
                for (NetworkInterface iface : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                    if (!iface.isUp() || iface.isLoopback()) continue;
                    for (var addr : Collections.list(iface.getInetAddresses())) {
                        if (addr instanceof Inet4Address && !addr.isLoopbackAddress()) {
                            addresses.add(addr.getHostAddress());
                        }
                    }
                }
            } catch (Exception ex) {
                log.warn("Unable to enumerate network addresses: {}", ex.getMessage());
            }
        }
        log.info("==================================================");
        log.info("SERVER STARTED | environment={} | bind={} | port={}", profile, bindAddress, port);
        log.info("LOCAL URL: http://127.0.0.1:{}/api/v1/health", port);
        for (String address : addresses) {
            log.info("NETWORK URL (if reachable): http://{}:{}/api/v1/health", address, port);
        }
        log.info("==================================================");
    }
}
