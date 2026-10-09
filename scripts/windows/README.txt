Windows background execution helper

Read the root README.md first. Each profile reads its own file: .env.local, .env.dev, .env.stage, or .env.prod. Create the needed file by copying the matching .env.<profile>.example template and configure Gmail settings in that file. Never commit real .env.<profile> files.

Local example from PowerShell in the project folder:
  Copy-Item .env.local.example .env.local
  .\scripts\windows\server.ps1 build local
  .\scripts\windows\server.ps1 start local

Stop only the app to test watchdog alerts:
  .\scripts\windows\server.ps1 stop local

The independent watchdog remains running so it can send an email if the app's health endpoint stops responding. After testing, stop the watchdog separately:
  .\scripts\windows\server.ps1 watchdog-stop local
