#!/usr/bin/env python3
"""External watchdog: remains alive when the Spring Boot monitoring app stops."""
import os
import time
import urllib.request
import urllib.error
import smtplib
import socket
from email.message import EmailMessage
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(os.environ.get("MONITORING_PROJECT_ROOT", Path(__file__).resolve().parent.parent))
PROFILE = os.environ.get("LOG_PROFILE", "local")
LOG_DIR = ROOT / "logs" / PROFILE / "error"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "monitoring-watchdog.log"

HEALTH_URL = os.environ.get("WATCHDOG_HEALTH_URL", "http://127.0.0.1:7001/api/v1/health")
CHECK_INTERVAL = max(2, int(os.environ.get("WATCHDOG_CHECK_INTERVAL_SECONDS", "10")))
ALERT_INTERVAL = max(1, int(os.environ.get("WATCHDOG_ALERT_INTERVAL_MINUTES", "1"))) * 60
MAX_ALERTS = max(1, int(os.environ.get("WATCHDOG_MAX_EMAILS", "10")))
TIMEOUT = max(1, int(os.environ.get("WATCHDOG_CONNECT_TIMEOUT_SECONDS", "3")))
INITIAL_DELAY = max(0, int(os.environ.get("WATCHDOG_INITIAL_DELAY_SECONDS", "30")))
FAILURE_THRESHOLD = max(1, int(os.environ.get("WATCHDOG_FAILURE_THRESHOLD", "2")))
MAIL_HOST = os.environ.get("MAIL_HOST", "smtp.gmail.com")
MAIL_PORT = int(os.environ.get("MAIL_PORT", "587"))
MAIL_USERNAME = os.environ.get("MAIL_USERNAME", "")
MAIL_PASSWORD = os.environ.get("MAIL_PASSWORD", "")
MAIL_TO = [x.strip() for x in os.environ.get("MONITOR_EMAIL_TO", "").split(",") if x.strip()]


def log(level, event, **fields):
    timestamp = datetime.now().astimezone().isoformat(timespec="seconds")
    suffix = " ".join(f"{k}={str(v).replace(' ', '_')}" for k, v in fields.items())
    line = f"timestamp={timestamp} level={level} service=monitoring-watchdog profile={PROFILE} event={event} {suffix}".rstrip()
    print(line, flush=True)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(line + "\n")
        f.flush()


def health_check():
    req = urllib.request.Request(HEALTH_URL, headers={"User-Agent": "msa-monitoring-watchdog/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            return 200 <= response.status < 300, f"http_status={response.status}"
    except Exception as exc:  # includes connection refused, timeout, HTTP errors
        return False, f"reason={type(exc).__name__}:{exc}"


def send_alert(count, detail):
    parsed = urlparse(HEALTH_URL)
    host = parsed.hostname or "unknown"
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    if not MAIL_USERNAME or not MAIL_PASSWORD or not MAIL_TO:
        log("ERROR", "WATCHDOG_EMAIL_FAILED", alert_number=count, reason="missing_mail_configuration", host=host, port=port)
        return False
    msg = EmailMessage()
    msg["From"] = MAIL_USERNAME
    msg["To"] = ", ".join(MAIL_TO)
    msg["Subject"] = f"[MSA Monitoring][ERROR] Monitoring server unavailable ({count}/{MAX_ALERTS})"
    msg.set_content(
        "The MSA monitoring server health endpoint is unreachable.\n\n"
        f"Service: monitoring\nHost/IP: {host}\nPort: {port}\nHealth URL: {HEALTH_URL}\n"
        f"Detected at: {datetime.now().astimezone().isoformat(timespec='seconds')}\n"
        f"Alert number: {count}/{MAX_ALERTS}\nDetails: {detail}\n\n"
        "This alert was sent by the independent project watchdog process."
    )
    try:
        with smtplib.SMTP(MAIL_HOST, MAIL_PORT, timeout=15) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.ehlo()
            smtp.login(MAIL_USERNAME, MAIL_PASSWORD)
            smtp.send_message(msg)
        log("INFO", "WATCHDOG_EMAIL_SENT", alert_number=count, max_alerts=MAX_ALERTS, host=host, port=port, recipients=len(MAIL_TO))
        return True
    except Exception as exc:
        log("ERROR", "WATCHDOG_EMAIL_FAILED", alert_number=count, host=host, port=port, reason=f"{type(exc).__name__}:{exc}")
        return False


def main():
    enabled = os.environ.get("WATCHDOG_ENABLED", "true").strip().lower() in ("1", "true", "yes", "on")
    if not enabled:
        log("INFO", "WATCHDOG_DISABLED", reason="WATCHDOG_ENABLED_false")
        while True:
            time.sleep(3600)
    log("INFO", "WATCHDOG_STARTED", health_url=HEALTH_URL, check_interval_seconds=CHECK_INTERVAL,
        alert_interval_minutes=ALERT_INTERVAL // 60, max_emails=MAX_ALERTS, initial_delay_seconds=INITIAL_DELAY)
    if INITIAL_DELAY:
        time.sleep(INITIAL_DELAY)
    failure_streak = 0
    alerts_sent = 0
    outage_active = False
    next_alert_at = 0.0
    limit_logged = False
    while True:
        healthy, detail = health_check()
        now = time.monotonic()
        if healthy:
            if outage_active:
                log("INFO", "WATCHDOG_SERVICE_RECOVERED", alerts_sent=alerts_sent)
            outage_active = False
            failure_streak = 0
            alerts_sent = 0
            next_alert_at = 0.0
            limit_logged = False
        else:
            failure_streak += 1
            if failure_streak >= FAILURE_THRESHOLD:
                if not outage_active:
                    outage_active = True
                    log("ERROR", "WATCHDOG_SERVICE_UNREACHABLE", health_url=HEALTH_URL, detail=detail, max_emails=MAX_ALERTS)
                    next_alert_at = now
                if alerts_sent < MAX_ALERTS and now >= next_alert_at:
                    sent = send_alert(alerts_sent + 1, detail)
                    if sent:
                        alerts_sent += 1
                    # Avoid rapid retry loops on SMTP failures; retry after configured interval.
                    next_alert_at = now + ALERT_INTERVAL
                elif alerts_sent >= MAX_ALERTS:
                    if not limit_logged:
                        log("WARN", "WATCHDOG_EMAIL_LIMIT_REACHED", alerts_sent=alerts_sent, max_emails=MAX_ALERTS)
                        limit_logged = True
                    next_alert_at = now + ALERT_INTERVAL
        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("WARN", "WATCHDOG_STOPPED", reason="SIGINT")
