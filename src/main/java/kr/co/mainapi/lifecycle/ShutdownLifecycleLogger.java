package kr.co.mainapi.lifecycle;

import jakarta.annotation.PreDestroy;
import java.util.Arrays;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

@Component
public class ShutdownLifecycleLogger {
    private static final Logger log = LoggerFactory.getLogger(ShutdownLifecycleLogger.class);
    private final AtomicBoolean notificationAttempted = new AtomicBoolean(false);
    private final JavaMailSender mailSender;
    private final boolean enabled;
    private final String recipient;
    private final String sender;
    private final String profile;

    public ShutdownLifecycleLogger(JavaMailSender mailSender,
            @Value("${LIFECYCLE_EMAIL_ENABLED:false}") boolean enabled,
            @Value("${MONITOR_EMAIL_TO:}") String recipient,
            @Value("${MAIL_USERNAME:}") String sender,
            @Value("${spring.profiles.active:local}") String profile) {
        this.mailSender = mailSender;
        this.enabled = enabled;
        this.recipient = recipient;
        this.sender = sender;
        this.profile = profile;
    }

    @PreDestroy
    public void onShutdown() {
        String reason = "JVM_GRACEFUL_SHUTDOWN";
        String reasonFile = System.getenv("SHUTDOWN_REASON_FILE");
        if (reasonFile != null && !reasonFile.isBlank()) {
            try {
                String saved = Files.readString(Path.of(reasonFile)).trim();
                if (saved.equals("MANUAL_STOP") || saved.equals("MANUAL_RESTART")) reason = saved;
            } catch (Exception ignored) { /* systemd may stop the JVM without a manual command */ }
        }
        log.info("event=APPLICATION_SHUTDOWN reason={}", reason);
        if (!notificationAttempted.compareAndSet(false, true)) {
            log.info("event=SHUTDOWN_EMAIL_SKIPPED reason=already_attempted");
            return;
        }
        if (!enabled || sender.isBlank() || recipient.isBlank()) {
            log.warn("event=SHUTDOWN_EMAIL_SKIPPED enabled={} senderConfigured={} recipientConfigured={}",
                    enabled, !sender.isBlank(), !recipient.isBlank());
            return;
        }
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(sender);
            String[] recipients = Arrays.stream(recipient.split(","))
                    .map(String::trim).filter(value -> !value.isBlank()).toArray(String[]::new);
            if (recipients.length == 0) {
                log.warn("event=SHUTDOWN_EMAIL_SKIPPED reason=no_valid_recipients");
                return;
            }
            message.setTo(recipients);
            message.setSubject("[MSA][" + profile + "] Monitoring server stopped (" + reason + ")");
            message.setText("Monitoring server is shutting down gracefully.\nProfile: " + profile + "\nReason: " + reason);
            mailSender.send(message);
            log.info("event=SHUTDOWN_EMAIL_SENT profile={} recipients={}", profile, recipients.length);
        } catch (Exception e) {
            log.error("event=SHUTDOWN_EMAIL_FAILED profile={} error={}", profile, e.toString());
        }
    }
}
