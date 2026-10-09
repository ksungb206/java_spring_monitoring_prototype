package kr.co.mainapi.monitoring;

import java.util.ArrayList;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "monitoring")
public class MonitoringProperties {
    private boolean enabled = true;
    private long intervalMs = 600000;
    private long initialDelayMs = 10000;
    private int connectTimeoutMs = 3000;
    private List<Target> targets = new ArrayList<>();
    private Email email = new Email();

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public long getIntervalMs() { return intervalMs; }
    public void setIntervalMs(long intervalMs) { this.intervalMs = intervalMs; }
    public long getInitialDelayMs() { return initialDelayMs; }
    public void setInitialDelayMs(long initialDelayMs) { this.initialDelayMs = initialDelayMs; }
    public int getConnectTimeoutMs() { return connectTimeoutMs; }
    public void setConnectTimeoutMs(int connectTimeoutMs) { this.connectTimeoutMs = connectTimeoutMs; }
    public List<Target> getTargets() { return targets; }
    public void setTargets(List<Target> targets) { this.targets = targets; }
    public Email getEmail() { return email; }
    public void setEmail(Email email) { this.email = email; }

    public static class Target {
        private String name;
        private String host;
        private int port;
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getHost() { return host; }
        public void setHost(String host) { this.host = host; }
        public int getPort() { return port; }
        public void setPort(int port) { this.port = port; }
    }

    public static class Email {
        private boolean enabled = false;
        private String recipients = "";
        public boolean isEnabled() { return enabled; }
        public void setEnabled(boolean enabled) { this.enabled = enabled; }
        public String getRecipients() { return recipients; }
        public void setRecipients(String recipients) { this.recipients = recipients; }
    }
}
