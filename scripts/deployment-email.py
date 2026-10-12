#!/usr/bin/env python3
"""Send build/deployment lifecycle alerts using the profile's .env file."""
import os
import smtplib
import ssl
import sys
from email.message import EmailMessage
from pathlib import Path

if len(sys.argv) != 4:
    sys.exit("Usage: deployment-email.py <profile> <event> <detail>")
profile, event, detail = sys.argv[1:]
if profile not in ("local", "dev", "stage", "prod") or event not in (
    "BUILD_FAILED", "BUILD_SUCCEEDED", "DEPLOY_FAILED", "DEPLOY_SUCCEEDED"
):
    sys.exit("Invalid profile/event")
root = Path(__file__).resolve().parent.parent
env_file = root / (".env." + profile)
config = {}
if env_file.is_file():
    for line in env_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        config[key.strip()] = value

def setting(key, default=""):
    return config.get(key, os.environ.get(key, default))

if setting("DEPLOY_EMAIL_ENABLED", "true").lower() != "true":
    print("event=DEPLOY_EMAIL_SKIPPED reason=disabled", flush=True)
    sys.exit(0)
username = setting("MAIL_USERNAME").strip()
password = setting("MAIL_PASSWORD").strip()
recipients = [x.strip() for x in setting("MONITOR_EMAIL_TO").split(",") if x.strip()]
if not username or not password or not recipients or "replace-with-" in password:
    print("event=DEPLOY_EMAIL_FAILED reason=mail_not_configured", file=sys.stderr, flush=True)
    sys.exit(1)
message = EmailMessage()
message["From"] = username
message["To"] = ", ".join(recipients)
message["Subject"] = f"[MSA][{profile}] {event}"
message.set_content(f"Profile: {profile}\nEvent: {event}\nDetail: {detail}\n")
try:
    host = setting("MAIL_HOST", "smtp.gmail.com")
    port = int(setting("MAIL_PORT", "587"))
    with smtplib.SMTP(host, port, timeout=12) as smtp:
        smtp.ehlo()
        smtp.starttls(context=ssl.create_default_context())
        smtp.ehlo()
        smtp.login(username, password)
        smtp.send_message(message)
    print(f"event=DEPLOY_EMAIL_SENT profile={profile} type={event} recipients={len(recipients)}", flush=True)
except Exception as exc:
    print(f"event=DEPLOY_EMAIL_FAILED profile={profile} type={event} error={type(exc).__name__}", file=sys.stderr, flush=True)
    sys.exit(1)
