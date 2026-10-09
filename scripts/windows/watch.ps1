param([ValidateSet('local','dev','stage','prod')][string]$ProfileName='local')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
# Load KEY=VALUE settings from the selected profile file (.env.local/.env.dev/.env.stage/.env.prod).
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
$log=Join-Path $root "logs/$ProfileName"
New-Item -ItemType Directory -Force $state,"$log/lifecycle","$log/error","$log/application" | Out-Null
function Write-Event($level,$event,$detail) {
  $line="timestamp=$((Get-Date).ToString('o')) level=$level service=main-api profile=$ProfileName event=$event $detail"
  Add-Content -LiteralPath "$log/lifecycle/lifecycle-$((Get-Date).ToString('yyyy-MM-dd')).log" -Value $line -Encoding UTF8
  if($level -eq 'ERROR'){Add-Content -LiteralPath "$log/error/error-$((Get-Date).ToString('yyyy-MM-dd')).log" -Value $line -Encoding UTF8}
}
try {
  $java=Get-Content -LiteralPath "$state/java.path" -Raw
  $java=$java.Trim()
  $jar=Join-Path $root 'target/main-api-spring-0.1.0.jar'
  while(-not (Test-Path "$state/stop.flag")) {
    $env:LOG_PROFILE=$ProfileName
    $out=Join-Path $log 'application/console-out.log';$err=Join-Path $log 'error/console-err.log'
    $p=Start-Process -FilePath $java -ArgumentList @('-jar',('"'+$jar+'"'),"--spring.profiles.active=$ProfileName") -WorkingDirectory $root -PassThru -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden
    Set-Content -LiteralPath "$state/server.pid" -Value $p.Id
    Write-Event 'INFO' 'SERVICE_START' "pid=$($p.Id)"
    $p.WaitForExit();$code=$p.ExitCode
    Remove-Item "$state/server.pid" -ErrorAction SilentlyContinue
    if(Test-Path "$state/stop.flag") { Write-Event 'INFO' 'SERVICE_STOPPED' "pid=$($p.Id) requested=manual exit=$code"; break }
    Write-Event 'ERROR' 'SERVICE_FAILED' "pid=$($p.Id) exit=$code auto_restart=true"
    Start-Sleep -Seconds 5
  }
} catch { Write-Event 'ERROR' 'WATCHDOG_FAILED' "message=$($_.Exception.Message)" }
finally {Remove-Item "$state/watch.pid" -ErrorAction SilentlyContinue}
