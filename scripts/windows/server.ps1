param([Parameter(Mandatory=$true)][ValidateSet('start','stop','restart','status','logs','build','watchdog-stop')][string]$Action,[ValidateSet('local','dev','stage','prod')][string]$ProfileName='local')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$envFile=Join-Path $root ".env.$ProfileName"
if(-not (Test-Path -LiteralPath $envFile)) { throw "Profile config not found: $envFile. Copy .env.$ProfileName.example to .env.$ProfileName and edit it." }
foreach($line in Get-Content -LiteralPath $envFile) {
 $trimmed=$line.Trim()
 if($trimmed -and -not $trimmed.StartsWith('#') -and $trimmed.Contains('=')) {
  $pair=$trimmed -split '=',2
  [Environment]::SetEnvironmentVariable($pair[0].Trim(),$pair[1].Trim(),'Process')
 }
}
$state=Join-Path $root "run/$ProfileName";$log=Join-Path $root "logs/$ProfileName"
New-Item -ItemType Directory -Force $state,"$log/lifecycle","$log/error","$log/application" | Out-Null
function Event($kind,$detail) {
 $line="timestamp=$((Get-Date).ToString('o')) level=INFO service=main-api profile=$ProfileName event=$kind $detail"
 Add-Content -LiteralPath "$log/lifecycle/lifecycle-$((Get-Date).ToString('yyyy-MM-dd')).log" -Value $line -Encoding UTF8
 Write-Host $line
}
function PidAlive($path) {
 if(-not (Test-Path $path)){return $false}
 $idNumber=0
 if(-not [int]::TryParse((Get-Content $path -Raw).Trim(),[ref]$idNumber)){return $false}
 return ($null -ne (Get-Process -Id $idNumber -ErrorAction SilentlyContinue))
}
function FindJava17 {
 $candidates=@()
 if($env:JAVA_HOME){$candidates+= (Join-Path $env:JAVA_HOME 'bin/java.exe')}
 $candidates+= @(Get-ChildItem 'C:\Program Files\Java','C:\Program Files\Eclipse Adoptium','C:\Program Files\Microsoft' -Recurse -Filter java.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
 $cmd=Get-Command java.exe -ErrorAction SilentlyContinue;if($cmd){$candidates+=$cmd.Source}
 foreach($c in $candidates){if(Test-Path $c){$v=(& $c -version 2>&1 | Out-String);if($v -match 'version "17\.' -or $v -match 'openjdk 17\.'){return $c}}}
 throw 'Java 17 not found. Install JDK 17 and set JAVA_HOME for this terminal (do not change system Java).'
}
function Build {
 $java=FindJava17
 $jdk=(Split-Path (Split-Path $java -Parent) -Parent)
 $env:JAVA_HOME=$jdk;$env:PATH=(Join-Path $jdk 'bin')+';'+$env:PATH
 $mvn=Get-Command mvn.cmd -ErrorAction SilentlyContinue
 if(-not $mvn){throw 'Maven not found. Install Maven and add its bin folder to PATH.'}
 Push-Location $root
 try { & $mvn.Source clean package; if($LASTEXITCODE -ne 0){throw 'Maven build failed'} }
 finally {Pop-Location}
 Set-Content -LiteralPath "$state/java.path" -Value $java
}
function StartExternalWatchdog {
 if(PidAlive "$state/email-watchdog.pid"){return}
 $hostExe=(Get-Process -Id $PID).Path
 if(-not $hostExe -or -not (Test-Path $hostExe)){$hostExe='powershell.exe'}
 $argsList=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $PSScriptRoot 'watchdog.ps1')+'"'),'-ProfileName',$ProfileName)
 $wd=Start-Process -FilePath $hostExe -ArgumentList $argsList -WorkingDirectory $root -WindowStyle Hidden -PassThru
 Set-Content -LiteralPath "$state/email-watchdog.pid" -Value $wd.Id
}
function StopServer {
 Event 'MANUAL_STOP' "requested_by=$env:USERNAME"
 Set-Content -LiteralPath "$state/stop.flag" -Value 'stop'
 if(PidAlive "$state/server.pid") {
   $serverId=[int](Get-Content "$state/server.pid" -Raw).Trim()
   Stop-Process -Id $serverId -ErrorAction SilentlyContinue
 }
 for($i=0;$i -lt 20 -and (PidAlive "$state/watch.pid");$i++){Start-Sleep -Milliseconds 500}
 if(PidAlive "$state/watch.pid") {Write-Warning 'Watcher still running. Check status.'}
 else {Remove-Item "$state/watch.pid","$state/server.pid" -ErrorAction SilentlyContinue}
 Write-Host 'STOPPED (manual stop; no automatic restart)'
}
switch($Action) {
 'build' {Build;break}
 'start' {
   if(PidAlive "$state/watch.pid"){StartExternalWatchdog;Write-Host 'Already running';break}
   if(-not (Test-Path "$root/target/main-api-spring-0.1.0.jar") -or -not (Test-Path "$state/java.path")){Build}
   Remove-Item "$state/stop.flag" -ErrorAction SilentlyContinue
   $hostExe=(Get-Process -Id $PID).Path
   if(-not $hostExe -or -not (Test-Path $hostExe)){$hostExe='powershell.exe'}
   $argsList=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $PSScriptRoot 'watch.ps1')+'"'),'-ProfileName',$ProfileName)
   $watch=Start-Process -FilePath $hostExe -ArgumentList $argsList -WorkingDirectory $root -WindowStyle Hidden -PassThru
   Set-Content -LiteralPath "$state/watch.pid" -Value $watch.Id
   StartExternalWatchdog
   Event 'MANUAL_START' "watch_pid=$($watch.Id)"
   Start-Sleep -Seconds 2
   & $PSCommandPath status $ProfileName
   break
 }
 'stop' {StopServer;break}
 'restart' {StopServer; & $PSCommandPath start $ProfileName;break}
 'watchdog-stop' {
   if(PidAlive "$state/email-watchdog.pid") { Stop-Process -Id ([int](Get-Content "$state/email-watchdog.pid" -Raw).Trim()) -Force -ErrorAction SilentlyContinue; Remove-Item "$state/email-watchdog.pid" -ErrorAction SilentlyContinue; Write-Host 'Email watchdog stopped' } else { Write-Host 'Email watchdog is not running' }
   break
 }
 'status' {
   $watchOk=PidAlive "$state/watch.pid";$serverOk=PidAlive "$state/server.pid";$emailWatchOk=PidAlive "$state/email-watchdog.pid"
   Write-Host "Email watchdog running: $emailWatchOk"
   Write-Host "Process supervisor running: $watchOk"
   Write-Host "Java server running: $serverOk"
   if($serverOk){Write-Host "Java PID: $((Get-Content "$state/server.pid" -Raw).Trim())"}
   Write-Host "Logs: $log"
   break
 }
 'logs' {
   $files=Get-ChildItem "$log/lifecycle" -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime
   if($files){Get-Content -LiteralPath $files[-1].FullName -Tail 50 -Wait}else{Write-Host 'No logs yet'}
   break
 }
}
