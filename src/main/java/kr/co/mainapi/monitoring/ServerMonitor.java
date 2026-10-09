package kr.co.mainapi.monitoring;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.MailException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class ServerMonitor {
    private static final Logger log = LoggerFactory.getLogger(ServerMonitor.class);
    private final MonitoringProperties properties;
    private final JavaMailSender mailSender;
    private final org.springframework.core.env.Environment environment;
    private final Map<String, Boolean> previousState = new ConcurrentHashMap<>();

    public ServerMonitor(MonitoringProperties properties, JavaMailSender mailSender, org.springframework.core.env.Environment environment) {
        this.properties = properties;
        this.mailSender = mailSender;
        this.environment = environment;
    }

    @Scheduled(fixedDelayString = "${monitoring.interval-ms:600000}", initialDelayString = "${monitoring.initial-delay-ms:10000}")
    public void checkConfiguredServers() {
        if (!properties.isEnabled()) {
            log.debug("event=MONITORING_SKIPPED reason=disabled");
            return;
        }
        for (MonitoringProperties.Target target : properties.getTargets()) {
            if (target.getHost() == null || target.getHost().isBlank() || target.getPort() < 1 || target.getPort() > 65535) {
                log.error("event=MONITOR_CONFIG_INVALID name={} host={} port={}", target.getName(), target.getHost(), target.getPort());
                continue;
            }
            String key = target.getName() + "@" + target.getHost() + ":" + target.getPort();
            boolean reachable = canConnect(target);
            Boolean wasReachable = previousState.put(key, reachable);
            if (reachable) {
                if (Boolean.FALSE.equals(wasReachable)) {
                    log.info("event=SERVER_RECOVERED name={} host={} port={}", target.getName(), target.getHost(), target.getPort());
                } else {
                    log.info("event=SERVER_CHECK_OK name={} host={} port={}", target.getName(), target.getHost(), target.getPort());
                }
            } else if (wasReachable == null || wasReachable) {
                log.error("event=SERVER_UNREACHABLE name={} host={} port={} checkedAt={}", target.getName(), target.getHost(), target.getPort(), OffsetDateTime.now());
                sendAlert(target);
            } else {
                log.warn("event=SERVER_STILL_UNREACHABLE name={} host={} port={}", target.getName(), target.getHost(), target.getPort());
            }
        }
    }

    private boolean canConnect(MonitoringProperties.Target target) {
        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress(target.getHost(), target.getPort()), properties.getConnectTimeoutMs());
            return true;
        } catch (IOException | IllegalArgumentException ex) {
            log.debug("event=SERVER_CHECK_FAILED name={} host={} port={} reason={}", target.getName(), target.getHost(), target.getPort(), ex.toString());
            return false;
        }
    }

    private void sendAlert(MonitoringProperties.Target target) {
        MonitoringProperties.Email email = properties.getEmail();
        String recipients = email.getRecipients();
        String username = environment.getProperty("spring.mail.username", "");
        if (!email.isEnabled() || recipients == null || recipients.isBlank() || username.isBlank() || environment.getProperty("spring.mail.password", "").isBlank()) {
            log.warn("event=EMAIL_ALERT_SKIPPED reason=email_not_configured target={} host={} port={}", target.getName(), target.getHost(), target.getPort());
            return;
        }
        List<String> to = Arrays.stream(recipients.split(",")).map(String::trim).filter(v -> !v.isBlank()).collect(Collectors.toList());
        if (to.isEmpty()) {
            log.warn("event=EMAIL_ALERT_SKIPPED reason=no_recipients target={}", target.getName());
            return;
        }
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(username);
        message.setTo(to.toArray(new String[0]));
        message.setSubject("[MSA Monitoring][ERROR] " + target.getName() + " is unreachable");
        message.setText("A monitored server could not be reached.\n\nService: " + target.getName() + "\nHost/IP: " + target.getHost() + "\nPort: " + target.getPort() + "\nChecked at: " + OffsetDateTime.now() + "\n\nPlease check the target server and its network/firewall settings.");
        try {
            mailSender.send(message);
            log.info("event=EMAIL_ALERT_SENT target={} host={} port={} recipients={}", target.getName(), target.getHost(), target.getPort(), to.size());
        } catch (MailException ex) {
            log.error("event=EMAIL_ALERT_FAILED target={} host={} port={} reason={}", target.getName(), target.getHost(), target.getPort(), ex.getMessage(), ex);
        }
    }
}
