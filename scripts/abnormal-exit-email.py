#!/usr/bin/env python3
"""Best-effort post-exit alert. Runs outside JVM via systemd ExecStopPost."""
import os, sys, smtplib, ssl
from email.message import EmailMessage
profile, result, code, status = sys.argv[1:5]
if os.getenv('LIFECYCLE_EMAIL_ENABLED', 'false').lower() != 'true':
    print('event=ABNORMAL_EXIT_EMAIL_SKIPPED reason=disabled', flush=True); sys.exit(0)
username=os.getenv('MAIL_USERNAME','').strip()
password=os.getenv('MAIL_PASSWORD','').strip()
to=[x.strip() for x in os.getenv('MONITOR_EMAIL_TO','').split(',') if x.strip()]
if not username or not password or not to or 'replace-with-' in password:
    print('event=ABNORMAL_EXIT_EMAIL_SKIPPED reason=mail_not_configured', flush=True); sys.exit(0)
msg=EmailMessage()
msg['From']=username
msg['To']=', '.join(to)
msg['Subject']=f'[MSA][{profile}] Monitoring server abnormal exit ({result})'
msg.set_content(f'Monitoring service stopped abnormally.\nProfile: {profile}\nSystemd result: {result}\nExit code: {code}\nExit status: {status}\nThis alert is sent AFTER the JVM exited by systemd, not before.\n')
try:
    host=os.getenv('MAIL_HOST','smtp.gmail.com'); port=int(os.getenv('MAIL_PORT','587'))
    with smtplib.SMTP(host,port,timeout=12) as smtp:
        smtp.ehlo(); smtp.starttls(context=ssl.create_default_context()); smtp.ehlo(); smtp.login(username,password); smtp.send_message(msg)
    print(f'event=ABNORMAL_EXIT_EMAIL_SENT profile={profile} result={result} recipients={len(to)}', flush=True)
except Exception as e:
    print(f'event=ABNORMAL_EXIT_EMAIL_FAILED profile={profile} error={type(e).__name__}', flush=True)
