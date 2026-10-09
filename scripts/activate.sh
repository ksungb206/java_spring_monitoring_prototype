#!/usr/bin/env bash
# Source in project shell: source ./scripts/activate.sh
# Only current shell is affected; OS defaults and other terminals stay unchanged.
_MAIN_API_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${_MAIN_API_ACTIVE:-}" ]]; then
  _MAIN_API_OLD_JAVA_HOME="${JAVA_HOME-}"
  _MAIN_API_OLD_PATH="$PATH"
  _MAIN_API_ACTIVE=1
fi
_main_api_java17() {
  local java_home=""
  for java_home in /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/temurin-17-*; do
    if [[ -x "$java_home/bin/java" && -x "$java_home/bin/javac" ]]; then
      export JAVA_HOME="$java_home"
      export PATH="$JAVA_HOME/bin:$PATH"
      return 0
    fi
  done
  echo 'ERROR: Java 17 JDK missing. Install Java 17, then source this script again.' >&2
  return 1
}
_main_api_java17 || return 1
_main_api_spring_run() {
  local profile="$1"
  command -v mvn >/dev/null 2>&1 || { echo 'ERROR: Maven missing. sudo apt install -y maven' >&2; return 127; }
  [[ -f "$_MAIN_API_ROOT/pom.xml" ]] || { echo 'ERROR: pom.xml missing' >&2; return 1; }
  (cd "$_MAIN_API_ROOT" && mvn spring-boot:run "-P$profile")
}
spring:local() { _main_api_spring_run local; }
spring:dev() { _main_api_spring_run dev; }
spring:stage() { _main_api_spring_run stage; }
spring:prod() { _main_api_spring_run prod; }
_main_api_service() { bash "$_MAIN_API_ROOT/scripts/systemd-manager.sh" "$@"; }
spring:start() { _main_api_service start "${1:-local}"; }
spring:stop() { _main_api_service stop "${1:-local}"; }
spring:restart() { _main_api_service restart "${1:-local}"; }
spring:status() { _main_api_service status "${1:-local}"; }
spring:logs() { _main_api_service logs "${1:-local}"; }
start:local() { _main_api_service start local; }
start:dev() { _main_api_service start dev; }
start:stage() { _main_api_service start stage; }
start:prod() { _main_api_service start prod; }
restart:local() { _main_api_service restart local; }
restart:dev() { _main_api_service restart dev; }
restart:stage() { _main_api_service restart stage; }
restart:prod() { _main_api_service restart prod; }
stop:local() { _main_api_service stop local; }
stop:dev() { _main_api_service stop dev; }
stop:stage() { _main_api_service stop stage; }
stop:prod() { _main_api_service stop prod; }
status:local() { _main_api_service status local; }
status:dev() { _main_api_service status dev; }
status:stage() { _main_api_service status stage; }
status:prod() { _main_api_service status prod; }
logs:local() { _main_api_service logs local; }
logs:dev() { _main_api_service logs dev; }
logs:stage() { _main_api_service logs stage; }
logs:prod() { _main_api_service logs prod; }
spring:deactivate() {
  if [[ -n "${_MAIN_API_ACTIVE:-}" ]]; then
    if [[ -n "$_MAIN_API_OLD_JAVA_HOME" ]]; then export JAVA_HOME="$_MAIN_API_OLD_JAVA_HOME"; else unset JAVA_HOME; fi
    export PATH="$_MAIN_API_OLD_PATH"
    unset _MAIN_API_ACTIVE _MAIN_API_OLD_JAVA_HOME _MAIN_API_OLD_PATH
  fi
  unset -f restart:local restart:dev restart:stage restart:prod spring:local spring:dev spring:stage spring:prod spring:start spring:stop spring:restart spring:status spring:logs start:local start:dev start:stage start:prod stop:local stop:dev stop:stage stop:prod status:local status:dev status:stage status:prod logs:local logs:dev logs:stage logs:prod spring:deactivate _main_api_service _main_api_spring_run _main_api_java17
}
