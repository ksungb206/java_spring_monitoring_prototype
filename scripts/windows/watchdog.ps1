param([ValidateSet('local','dev','stage','prod')][string]$ProfileName='local')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$envFile=Join-Path $root ".env.$ProfileName"
if(Test-Path $envFile) {
  foreach($line in Get-Content -LiteralPath $envFile) {
    $trimmed=$line.Trim()
    if($trimmed -and -not $trimmed.StartsWith('#') -and $trimmed.Contains('=')) {
      $pair=$trimmed -split '=',2
      [Environment]::SetEnvironmentVariable($pair[0].Trim(),$pair[1].Trim(),'Process')
    }
  }
}
$state=Join-Path $root "run/$ProfileName"
$log=Join-Path $root "logs/$ProfileName/error/monitoring-watchdog.log"
New-Item -ItemType Directory -Force $state,(Split-Path $log -Parent) | Out-Null
function Write-Event($level,$event,$detail) {
  $line="timestamp=$((Get-Date).ToString('o')) level=$level service=monitoring-watchdog profile=$ProfileName event=$event $detail"
  Add-Content -LiteralPath $log -Value $line -Encoding UTF8
}
function Send-Alert($count,$detail) {
  $url=[string]$env:WATCHDOG_HEALTH_URL
  if(-not $url){$url='http://127.0.0.1:7001/api/v1/health'}
  $uri=[Uri]$url
  $hostName=$uri.Host;$port=$uri.Port
  if(-not $env:MAIL_USERNAME -or -not $env:MAIL_PASSWORD -or -not $env:MONITOR_EMAIL_TO) {
    Write-Event 'ERROR' 'WATCHDOG_EMAIL_FAILED' "alert_number=$count reason=missing_mail_configuration host=$hostName port=$port";return $false
  }
  try {
    $msg=New-Object System.Net.Mail.MailMessage
    $msg.From=$env:MAIL_USERNAME
    foreach($recipient in ($env:MONITOR_EMAIL_TO -split ',')) { if($recipient.Trim()){[void]$msg.To.Add($recipient.Trim())} }
    $msg.Subject="[MSA Monitoring][ERROR] Monitoring server unavailable ($count/$script:maxEmails)"
    $msg.Body="The MSA monitoring server health endpoint is unreachable.`r`n`r`nService: monitoring`r`nHost/IP: $hostName`r`nPort: $port`r`nHealth URL: $url`r`nDetected at: $((Get-Date).ToString('o'))`r`nAlert number: $count/$script:maxEmails`r`nDetails: $detail`r`n`r`nThis alert was sent by the independent project watchdog process."
    $smtpHost=[string]$env:MAIL_HOST;if(-not $smtpHost){$smtpHost='smtp.gmail.com'}
    $smtpPort=587;if($env:MAIL_PORT){$smtpPort=[int]$env:MAIL_PORT}
    $smtp=New-Object System.Net.Mail.SmtpClient($smtpHost,$smtpPort)
    $smtp.EnableSsl=$true
    $smtp.Credentials=New-Object System.Net.NetworkCredential([string]$env:MAIL_USERNAME,[string]$env:MAIL_PASSWORD)
    $smtp.Send($msg);$msg.Dispose();$smtp.Dispose()
    Write-Event 'INFO' 'WATCHDOG_EMAIL_SENT' "alert_number=$count max_emails=$script:maxEmails host=$hostName port=$port";return $true
  } catch { Write-Event 'ERROR' 'WATCHDOG_EMAIL_FAILED' "alert_number=$count host=$hostName port=$port reason=$($_.Exception.Message -replace '\s+','_')";return $false }
}
$enabled=([string]$env:WATCHDOG_ENABLED -ne 'false')
if(-not $enabled){Write-Event 'INFO' 'WATCHDOG_DISABLED' 'reason=WATCHDOG_ENABLED_false';exit 0}
$url=[string]$env:WATCHDOG_HEALTH_URL;if(-not $url){$url='http://127.0.0.1:7001/api/v1/health'}
$checkSeconds=10;if($env:WATCHDOG_CHECK_INTERVAL_SECONDS){$checkSeconds=[Math]::Max(2,[int]$env:WATCHDOG_CHECK_INTERVAL_SECONDS)}
$script:alertMinutes=1;if($env:WATCHDOG_ALERT_INTERVAL_MINUTES){$script:alertMinutes=[Math]::Max(1,[int]$env:WATCHDOG_ALERT_INTERVAL_MINUTES)}
$script:maxEmails=10;if($env:WATCHDOG_MAX_EMAILS){$script:maxEmails=[Math]::Max(1,[int]$env:WATCHDOG_MAX_EMAILS)}
$timeout=3;if($env:WATCHDOG_CONNECT_TIMEOUT_SECONDS){$timeout=[Math]::Max(1,[int]$env:WATCHDOG_CONNECT_TIMEOUT_SECONDS)}
$initialDelay=30;if($env:WATCHDOG_INITIAL_DELAY_SECONDS){$initialDelay=[Math]::Max(0,[int]$env:WATCHDOG_INITIAL_DELAY_SECONDS)}
$threshold=2;if($env:WATCHDOG_FAILURE_THRESHOLD){$threshold=[Math]::Max(1,[int]$env:WATCHDOG_FAILURE_THRESHOLD)}
Write-Event 'INFO' 'WATCHDOG_STARTED' "health_url=$url check_interval_seconds=$checkSeconds alert_interval_minutes=$script:alertMinutes max_emails=$script:maxEmails initial_delay_seconds=$initialDelay"
Start-Sleep -Seconds $initialDelay
$failures=0;$sent=0;$outage=$false;$nextAlert=[datetime]::MinValue;$limitLogged=$false
while($true) {
  $healthy=$false;$detail=''
  try { $response=Invoke-WebRequest -Uri $url -TimeoutSec $timeout -UseBasicParsing; $healthy=($response.StatusCode -ge 200 -and $response.StatusCode -lt 300);$detail="http_status=$($response.StatusCode)" }
  catch { $detail="reason=$($_.Exception.GetType().Name):$($_.Exception.Message -replace '\s+','_')" }
  if($healthy) {
    if($outage){Write-Event 'INFO' 'WATCHDOG_SERVICE_RECOVERED' "alerts_sent=$sent"}
    $failures=0;$sent=0;$outage=$false;$nextAlert=[datetime]::MinValue;$limitLogged=$false
  } else {
    $failures++
    if($failures -ge $threshold) {
      if(-not $outage){$outage=$true;Write-Event 'ERROR' 'WATCHDOG_SERVICE_UNREACHABLE' "health_url=$url detail=$($detail -replace '\s+','_') max_emails=$script:maxEmails";$nextAlert=[datetime]::MinValue}
      if($sent -lt $script:maxEmails -and (Get-Date) -ge $nextAlert) {
        if(Send-Alert ($sent+1) $detail){$sent++}
        $nextAlert=(Get-Date).AddMinutes($script:alertMinutes)
      } elseif($sent -ge $script:maxEmails -and -not $limitLogged) {
        Write-Event 'WARN' 'WATCHDOG_EMAIL_LIMIT_REACHED' "alerts_sent=$sent max_emails=$script:maxEmails";$limitLogged=$true
      }
    }
  }
  Start-Sleep -Seconds $checkSeconds
}
