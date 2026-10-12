# MSA 장애 모니터링 및 서비스 복구 자동화 프로젝트

**Node.js NestJS 기반 프로젝트를 Java 17 / Spring Boot 3.3.5로 전환한 모니터링 및 장애 대응 프로토타입**

Java 17 · Spring Boot 3.3.5 · MyBatis · Maven · Ubuntu / WSL(systemd) · Gmail SMTP

## 1. 프로젝트 목적과 출발점

본 프로젝트는 기존 Node.js NestJS 기반 프로젝트를 Java Spring Boot로 컨버팅한 버전이다. 프레임워크 전환을 출발점으로 MSA 서비스의 연결 장애를 감지하고, 장애 발생 사실을 운영자에게 알리며, 서버별 복구 시나리오를 검증하기 위한 포트폴리오용 프로토타입이다.

**모니터링 서버와 개별 MSA 서버의 책임은 구분한다.** 모니터링 서버는 대상 서비스의 TCP 연결 상태 감지와 장애 이메일 통지를 담당한다. 자동 복구 시도, 정상화 확인, 복구 이력 기록 및 결과 알림은 향후 Main/OAuth/Log/Socket 등 **각 서버별 시나리오**로 적용한다. 현재 LOCAL 배포 복구 기능을 모든 MSA 서버에 이미 적용한 것은 아니다.

## 2. 사용자 요구사항

| 요구사항 | 현재 구현 및 계획 |
| --- | --- |
| NestJS 기반 프로젝트를 Java Spring Boot로 전환 | Java 17 / Spring Boot 3.3.5 / Maven 기반 구성 |
| MAIN을 포함한 MSA 서버 감시 | Main, OAuth, Log, Socket TCP 감시 대상으로 설정 |
| MSA 장애 시 운영자 이메일 발송 | Gmail SMTP 장애 알림 구현, 향후 Slack/SMS 확장 |
| 정상 종료와 비정상 종료 구분 | JVM 종료 처리와 systemd 종료 후처리 활용 |
| 환경별 독립 실행 및 설정 | LOCAL/DEV/STAGE/PROD 구성 |
| 빌드 실패 시 기존 서비스 보호 | Maven 실패 시 배포 중단 |
| 배포 후 정상화 검증 | HTTP Health Check |
| 배포 실패 시 이전 버전 복구 | JAR 백업 및 자동 롤백, 일부 시나리오 검증 |
| 서버별 장애 복구 시나리오 | 개별 MSA 서버에 추후 적용할 구조로 분리 |
| 장애 및 복구 이력 저장 | 현재 로컬 로그 활용, 보관 기간 정책은 추가 필요 |
| 중앙 백업 서버 | 현재 로컬 환경 제약으로 미구현, 향후 구축 |
| 실패 사례와 해결 방법 기록 | 아래 5장과 상세 가이드에 기록 |

## 3. 요구사항에 대한 기술적 총평

요구사항의 강점은 정상 동작뿐 아니라 **장애 감지 → 통지 → 서버별 복구 시도 → 정상화 검증 → 결과 기록**을 분리하여 검증하려는 점이다. 특히 빌드 실패가 기존 서비스에 영향을 주지 않도록 하고, 배포 실패 시 이전 JAR를 복원하도록 요구한 것은 운영 안정성 측면에서 적절하다.

다만 TCP 연결 성공은 애플리케이션의 핵심 기능 정상 동작을 보장하지 않는다. 서비스별 장애 판정 기준, 재시작 횟수 제한, 복구 성공 조건, 로컬 로그 보관 기간 및 중앙 백업 정책을 추가로 정의해야 한다. 현 단계는 단일 호스트의 **운영 자동화 프로토타입**이지 완전한 고가용성 또는 무중단 복구 시스템이 아니다.

## 4. 구현 구조와 서버별 시나리오

### A. MSA 모니터링 및 알림

모니터링 서버가 설정된 대상에 TCP 연결을 시도하고, 연결 실패 시 장애 로그와 Gmail 알림을 남긴다. 같은 장애가 지속되면 중복 메일을 줄이도록 이전 상태를 기억한다. 향후 Slack 및 문자(SMS) 알림을 추가한다.

| 감시 대상 | 기본 호스트 | 기본 포트 | 환경변수 |
| --- | --- | --- | --- |
| Main | 127.0.0.1 | 7191 | `MONITOR_MAIN_HOST`, `MONITOR_MAIN_PORT` |
| OAuth | 127.0.0.1 | 7102 | `MONITOR_OAUTH_HOST`, `MONITOR_OAUTH_PORT` |
| Log | 127.0.0.1 | 7103 | `MONITOR_LOG_HOST`, `MONITOR_LOG_PORT` |
| Socket | 127.0.0.1 | 7104 | `MONITOR_SOCKET_HOST`, `MONITOR_SOCKET_PORT` |

**포트 주의:** 7192/7193/7194는 이전 문서에서 사용한 서비스 포트 예시이며, 현재 `application.yml`의 OAuth/Log/Socket 기본값은 7102/7103/7104다. 실제 대상 서비스 포트는 환경별 `.env.*`의 `MONITOR_*_PORT`로 명시해야 한다. MAIN의 기본 포트는 7191이다.

### B. 개별 MSA 서버 자동 복구

각 서버는 자신의 장애 상황에 맞게 **장애 발생 → 복구 시도 → Health Check → 결과 기록 및 이메일 알림**을 구현하는 것이 목표다. 현재 LOCAL systemd 재시작과 JAR 롤백 구조를 구현했지만 모든 MSA 서버에 동일하게 적용한 것은 아니다.

### C. 장애 기록 및 백업

장애 발생과 복구 결과는 이메일로 통지하고 각 서버의 로컬 로그에도 일정 기간 보관하는 것을 목표로 한다. 현재 배포 로그와 systemd 로그를 확인할 수 있으나 **보관 기간 자동 관리**는 추가 구현이 필요하다. 별도 중앙 백업 서버가 바람직하지만 현재 로컬 서버 환경에서는 운영이 어려워 향후 과제로 남긴다.

## 5. 검증 결과, 주요 이슈 및 해결 방향 (2026-10-12)

| 테스트 및 이슈 | 확인 결과 | 해결 방향 / 후속 작업 |
| --- | --- | --- |
| 정상 Maven 빌드 및 배포 | 성공 이메일, Health Check HTTP 200 확인 | 지속 회귀 테스트 |
| `pom.xml` 오류 | 빌드 실패 이메일 확인, 기존 서비스 유지 | 빌드 단계에서 배포 중단 유지 |
| Health Check 강제 실패 | 이전 JAR 자동 롤백 성공 | 실제 신규 JAR 장애로 재검증 |
| SMTP 강제 실패 | 이메일 실패 로그 남기고 배포 지속 | 알림 장애의 별도 관측 수단 검토 |
| Java 실행 차단 테스트 | 신규/이전 JAR 모두 실행 차단되어 롤백 실패 | 신규 JAR에만 장애를 주입하도록 테스트 수정 |
| Spring 설정 오류 테스트 | 배포 전 Maven 통합 테스트에서 실패 | 빌드 통과 후 실제 실행 실패를 재현 |
| 운영 중 API 무응답 | 프로세스 생존만으로는 탐지 어려움 | 상시 Health Check와 복구 정책 추가 |
| 호스트/WSL 중단 | 내부 감시도 함께 중단 가능 | 외부 감시 및 중앙 백업 서버 검토 |
| MAIN 서버 TCP 장애 감지 및 Gmail 알림 (2026-10-12) | **성공**: 23:29:34 KST `SERVER_UNREACHABLE name=main host=127.0.0.1 port=7191` 기록, 23:29:38 KST `EMAIL_ALERT_SENT target=main recipients=1` 기록, 사용자 Gmail 실제 수신 확인, 모니터링 서비스 `active` 유지 | MAIN TCP 복구 감지(`SERVER_RECOVERED`)는 미검증. 현재 복구 이메일은 발송하지 않음 |

마지막 LOCAL 테스트에서 `main-api-local.service`는 정상 실행 중이었고 `/api/v1/health`가 HTTP 200을 반환했다. MAIN 장애 감지 당시에도 서비스 상태는 `active`였다. 장애 메일은 첫 연결 실패 시 발송하며 같은 장애가 지속되는 동안 매 검사마다 재발송하지 않는다. 단, 모니터링 서버 재시작 시 이전 상태가 초기화되므로 장애 메일이 다시 발송될 수 있다. **실제 신규 JAR 실행 실패 후 자동 롤백 성공은 아직 미검증**이다.

## 6. 설치, 실행 및 상세 검증 가이드

아래는 기존 README의 환경별 설정, 설치 방법, 실행 명령어, Gmail 설정, 테스트 및 장애 이슈, DEV 자동 배포 가이드를 보존한 내용이다.

### 6.1 환경별 설정 파일

`.example` 파일을 사용하지 않습니다. 프로젝트 ZIP에는 아래 네 파일이 있으며 각 파일 상단에 **환경의 목적과 설정 변수 설명**을 적었습니다.

| 파일 | 용도 | 기본 포트 | 실행 명령 |
| --- | --- | --- | --- |
| `.env.local` | 개인 PC, WSL에서 로컬 개발과 메일 기능 확인 | 7001 | `start:local` |
| `.env.dev` | 개발 서버에서 기능 통합 테스트 | 7002 | `start:dev` |
| `.env.stage` | 운영 배포 전 사전 검증 | 7003 | `start:stage` |
| `.env.prod` | 운영 서버에서 실제 MSA 상태 감시 | 7004 | `start:prod` |

각 파일에서 `MONITOR_MAIN_HOST`, `MONITOR_OAUTH_HOST`, `MONITOR_LOG_HOST`, `MONITOR_SOCKET_HOST` 및 대응 포트를 실제 서버 주소에 맞게 변경하세요. 프로필마다 발신자, 수신자, 검사 주기 등을 독립적으로 설정할 수 있습니다.

**주의:** 이 ZIP의 `.env.*` 파일에는 예시 Gmail 계정과 비밀번호만 들어 있습니다. 실제 Gmail 앱 비밀번호를 채워 넣은 `.env.*`는 `.gitignore`에 의해 Git 추적에서 제외됩니다. 따라서 **ZIP에는 설정 파일이 포함되지만 GitHub에서 새로 clone한 저장소에는 해당 파일이 없을 수 있습니다.** Git 배포 시에는 비밀정보를 제외한 설정 파일을 안전하게 배포하는 방식(배포 시스템의 secret 주입 등)을 별도로 마련해야 합니다. 실제 비밀번호를 GitHub에 올리지 마세요.

### 6.2 준비 및 빌드

Ubuntu 또는 WSL Ubuntu에서 systemd를 사용합니다. JDK 17, Maven, Python 3가 필요합니다. Maven은 프로젝트 의존성을 내려받지만 JDK나 Maven 프로그램 자체를 설치하지는 않습니다.

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk maven python3
cd /path/to/main_api_spring_mybatis
mvn clean install
```

`BUILD SUCCESS`가 표시되면 빌드 성공입니다. 빌드 중 권한 문제가 생기면 해당 경로의 쓰기 권한을 확인하세요.

### 6.3 local 환경 실행

```bash
# 메일 알림을 사용하려면 먼저 .env.local을 편집하세요.
nano .env.local
# MAIL_USERNAME / MAIL_PASSWORD / MONITOR_EMAIL_TO 입력
source ./scripts/activate.sh
start:local
status:local
curl http://localhost:7001/api/v1/health
```

정상 응답은 `code: 200`과 `data.status: ok`를 포함합니다. `source` 명령은 새 터미널마다 다시 실행해야 합니다. 처음 실행하거나 프로젝트 경로가 바뀐 경우 `start:local`이 systemd 유닛을 재설치하며 Maven 빌드를 다시 수행할 수 있습니다.

종료, 재시작, 로그 확인:

```bash
stop:local
restart:local
status:local
logs:local
```

각 명령의 `local`을 `dev`, `stage`, `prod`로 바꾸면 해당 프로필에 적용됩니다. **같은 머신에서 여러 프로필을 동시에 실행하려면 각 포트가 충돌하지 않아야 합니다.**

### 6.4 메일 설정

각 `.env.*`에서 다음 항목을 설정합니다.

```dotenv
MONITORING_ENABLED=true
MONITORING_EMAIL_ENABLED=true
LIFECYCLE_EMAIL_ENABLED=true
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-sender@gmail.com
MAIL_PASSWORD=replace-with-google-app-password
MONITOR_EMAIL_TO=your-recipient@example.com
```

`MAIL_PASSWORD`에는 Gmail **앱 비밀번호**를 사용합니다. 일반 로그인 비밀번호가 아닙니다. 설정을 바꾸면 해당 프로필의 서비스를 재시작해야 적용됩니다.

### 6.5 장애 및 종료 이메일 검증

현재 기본값은 `MONITORING_INTERVAL_MS=600000`(10분), 첫 검사 지연은 1초입니다. 실제 MSA가 해당 포트에서 실행 중이지 않으면 장애를 감지할 수 있습니다.

```bash
start:local
sudo journalctl -u main-api-local.service -n 150 --no-pager | grep -E 'SERVER_UNREACHABLE|EMAIL_ALERT_SENT|EMAIL_ALERT_FAILED'
stop:local
sudo journalctl -u main-api-local.service -n 150 --no-pager | grep -E 'APPLICATION_SHUTDOWN|SHUTDOWN_EMAIL_SENT|SHUTDOWN_EMAIL_FAILED|ABNORMAL_EXIT_EMAIL'
```

- **MSA 장애:** Spring 스케줄러가 TCP 연결 실패를 감지하면 알림 메일 발송을 시도합니다.
- **정상 종료:** `stop:local` 등으로 정상 종료하면 JVM 종료 처리에서 이메일 발송을 시도합니다.
- **비정상 종료:** systemd `ExecStopPost`가 프로세스 종료 후 별도 Python SMTP 스크립트로 이메일 발송을 시도합니다. 비정상 종료 직전 이메일을 보낼 수 있는 것은 아닙니다.
- **제약:** PC/WSL 자체 종료, 네트워크 단절, 전원 차단, SMTP 장애 등에서는 이메일 발송을 보장할 수 없습니다. 이런 경우에는 다른 머신에서 동작하는 외부 감시가 필요합니다.

### 6.6 프로젝트 구성

| 경로 | 설명 |
| --- | --- |
| `pom.xml` | Maven 빌드 및 의존성 |
| `src/` | Spring Boot / MyBatis 소스와 설정 |
| `scripts/activate.sh` | 환경별 실행 명령을 현재 셸에 등록 |
| `scripts/systemd-manager.sh` | systemd 서비스 설치, 실행, 중지, 상태 및 로그 관리 |
| `scripts/setup-deploy-checkouts.sh` | 환경별 독립 배포 체크아웃 생성 및 `.env` 초기 복사 |
| `scripts/service-start.sh`, `scripts/service-exit.sh` | 서비스 시작/종료 후처리 |
| `scripts/abnormal-exit-email.py` | 비정상 종료 후 이메일 전송 시도 |
| `.env.local`, `.env.dev`, `.env.stage`, `.env.prod` | 환경별 설정 파일 |

### 6.7 운영 주의사항

- 비밀정보가 포함된 `.env.*`는 Git에 커밋하지 마세요. `git status --short` 및 `git ls-files`로 추적 여부를 확인하세요.
- `start:<환경>` 명령은 systemd를 사용하므로 `systemd`가 PID 1로 실행되어야 합니다.
- 이 ZIP은 모니터링 서버 프로젝트이며, 실제 Main/OAuth/Log/Socket MSA 서버의 구현은 포함하지 않습니다.
- 환경별 메일 발송과 비정상 종료 처리는 배포할 서버에서 직접 검증해야 합니다.

### 6.8 DEV 자동 배포 (GitHub Actions + 로컬 WSL)

**현재 구현 및 검증 범위는 DEV 단일 WSL 프로토타입입니다.** `dev` 브랜치 Push를 감지해 GitHub Actions가 온라인 상태인 self-hosted Runner에 배포 작업을 할당합니다. Runner가 설치된 **그 WSL 내부**에서 Maven 빌드, Spring Boot systemd 재시작, 헬스체크를 수행합니다. `stage`, `prod`, EC2 자동 배포는 아직 이 워크플로의 대상이 아닙니다.

### 코드만 Clone하면 자동 배포되나요?

**아니요.** 저장소의 `.github/workflows/deploy.yml`과 배포 스크립트는 배포 절차를 정의하지만, 실제 배포 대상 WSL에는 **최초 1회 서버 설정**이 필요합니다. GitHub-hosted Runner만으로 빌드/테스트하는 경우와 달리, 이 프로젝트는 개발자의 로컬 WSL에서 서비스를 실행하기 때문입니다.

| 구분 | 저장소(코드) | 개발자 WSL(서버) |
| --- | --- | --- |
| 배포 트리거 | `.github/workflows/deploy.yml`: 원격 `dev` Push | Runner가 온라인이어야 작업 수신 |
| 실행 도구 | `scripts/deploy-branch.sh` 등 | Java 17, Maven, Git, curl, Python 3 |
| 배포 대상 | 코드와 설정 절차만 포함 | `~/deploy-checkouts/dev`의 별도 `dev` 체크아웃 |
| 실행 서비스 | systemd 설치 스크립트 포함 | `main-api-dev.service`, 기본 포트 7002 |
| 인증/환경 | 비밀번호·토큰 커밋 금지 | 로컬 `.env.dev`, Git 인증, Runner 등록 토큰(최초 등록 시) |
| 자동 실행 | GitHub Actions가 Job 생성 | Runner systemd 서비스가 Job 수신·실행 |

### 최초 1회: 각 개발자의 WSL 설정

1. Windows에서 **WSL2 Ubuntu**를 설치하고 WSL 안에서 systemd를 활성화합니다. `/etc/wsl.conf`에 아래 내용을 설정한 뒤 **Windows PowerShell에서** `wsl --shutdown`을 실행하고 Ubuntu를 다시 엽니다.

   ```ini
   [boot]
   systemd=true
   ```

2. WSL에서 Java 17, Maven 등 필요한 프로그램을 준비하고, GitHub 저장소를 Clone합니다. **비공개 저장소 Clone 권한**이 필요합니다.

   ```bash
   sudo apt update
   sudo apt install -y openjdk-17-jdk maven git curl tar python3 sudo
   # visudo가 없는 경우 sudo 패키지 설치 상태 확인
   cd /path/to/your/clone
   ```

3. 저장소 루트에 **본인의 `.env.dev`**를 준비합니다. 비밀번호를 Git에 올리지 마세요. GitHub 저장소의 **Settings → Actions → Runners → New self-hosted runner**에서 유효기간이 짧은 등록 토큰을 발급합니다(등록 권한 필요).

4. WSL 저장소 루트에서 아래 명령을 실행합니다. **토큰을 셸 기록·공유 로그에 노출하지 않도록 주의**하세요.

   ```bash
   # 토큰 입력 시 터미널에 표시하지 않음
   read -rsp 'Runner registration token: ' GITHUB_RUNNER_TOKEN; echo
   export GITHUB_RUNNER_TOKEN
   bash scripts/bootstrap-wsl-dev.sh
   unset GITHUB_RUNNER_TOKEN
   ```

   이 스크립트는 `~/deploy-checkouts/dev` 준비, `main-api-dev.service` 설치, 제한된 systemctl 권한 설정, `~/actions-runner-dev` Runner 등록 및 systemd 서비스 활성화를 수행합니다. 앱 서비스는 설치만 하고, 배포 시 시작/재시작합니다. **Runner 설치와 GitHub 저장소 등록에는 네트워크·권한·토큰이 필요하므로 완전한 무설정 설치는 아닙니다.**

5. 이미 `~/actions-runner`에 Runner를 설치해 사용 중이라면 새 Runner가 중복 등록될 수 있습니다. 기존 Runner를 재사용할지, 새 `~/actions-runner-dev`를 설치할지 결정한 뒤 진행하세요. **기존 Runner 폴더를 삭제하거나 덮어쓰지 마세요.** 기존 Runner를 쓰는 경우 GitHub Runner 라벨에 `deploy-dev`가 필요하며, systemd 실행과 배포 서비스 권한을 별도로 확인해야 합니다.

자세한 절차와 제약: [WSL DEV 무인 배포 가이드](docs/wsl-dev-unattended.md).

### 설치 상태 확인

```bash
# DEV 독립 체크아웃과 브랜치
git -C "$HOME/deploy-checkouts/dev" branch --show-current
test -f "$HOME/deploy-checkouts/dev/.env.dev" && echo '[OK] .env.dev'

# 앱 서비스의 설치·실행 상태 (최초 배포 전에는 inactive일 수 있음)
systemctl is-enabled main-api-dev.service
systemctl is-active main-api-dev.service
systemctl show main-api-dev.service -p WorkingDirectory --value

# 새 bootstrap으로 등록한 Runner인 경우
cat "$HOME/actions-runner-dev/.service"
systemctl is-active "$(cat "$HOME/actions-runner-dev/.service")"
```

Runner는 GitHub **Settings → Actions → Runners**에서 온라인 상태 및 `deploy-dev` 라벨을 확인합니다. 기존 Runner를 재사용한다면 그 Runner의 서비스 이름을 사용하세요. `main-api-dev.service`가 `disabled`여도 현재 `active`이면 실행 중일 수 있습니다. 단, WSL 부팅 시 앱 자체 자동 시작까지 원한다면 별도로 enable 설정을 검토해야 합니다.

### 실제 배포 흐름과 성공 확인

1. 개발자는 기능 브랜치(예: `feat/ksb/local`)에서 작업합니다. 로컬 Merge만으로 배포되지 않습니다.
2. 변경 사항을 원격 `dev`에 병합하고 Push합니다.
3. GitHub Actions가 `self-hosted`, `linux`, `deploy-dev` 라벨을 가진 **온라인 Runner 한 대**에 작업을 할당합니다.
4. Runner가 자신의 `~/deploy-checkouts/dev`에서 `dev` 브랜치를 업데이트하고 Maven 빌드/테스트, `main-api-dev.service` 재시작, 헬스체크를 수행합니다. 실패 시 배포 스크립트가 복구를 시도하지만 모든 장애 복구가 보장되는 것은 아닙니다.
5. **GitHub Actions Job이 Success인지 확인한 다음**, 실제 실행 WSL에서 응답을 확인합니다.

   ```bash
   curl -fsS http://localhost:7002/api/v1/health
   ```

2026-10-10 단일 WSL 검증에서 `dev` 커밋 `36af100` 배포 Job은 Success였고, 응답의 `data.status`가 `result_ok`에서 `result_ok_deploy_v2`로 변경됐습니다. 이는 **해당 WSL의 DEV 배포 검증 결과**이지 모든 개발자 PC의 자동 배포를 뜻하지 않습니다.

### 운영상 제약과 문제 해결

- **WSL/Windows가 종료되어 있으면 GitHub가 Runner를 깨울 수 없습니다.** Runner systemd 자동 시작은 WSL이 실행된 이후에만 동작합니다. Windows 로그인/부팅 후 WSL 실행 자동화는 별도 설정·검증이 필요합니다.
- **다수 개발자에게 동시 배포되지 않습니다.** 동일한 `deploy-dev` 라벨의 Runner가 여러 대여도 한 Job은 그중 **한 대**에서만 실행됩니다. 각자의 WSL에 모두 배포하려면 고유 Runner 식별 및 Job 분기(fan-out) 또는 별도 pull 방식이 필요합니다.
- `Missing local DEV checkout`: `~/deploy-checkouts/dev`와 Git 체크아웃 상태를 확인하고 초기 설정을 진행하세요.
- `Missing .env.dev`: 배포 체크아웃에 환경 파일이 있는지 확인하세요. 실제 값은 출력하거나 커밋하지 마세요.
- `WorkingDirectory mismatch`: `main-api-dev.service`의 작업 경로가 DEV 독립 체크아웃을 가리키도록 유닛을 재설치하세요.
- Job이 `queued`에 머무르면 Runner 온라인 상태, `deploy-dev` 라벨, systemd 서비스 상태를 확인하세요.
- Job 실패 또는 헬스체크 실패 시 `sudo journalctl -u main-api-dev.service -n 150 --no-pager`로 서버 로그를 확인하세요. 로그 공유 시 비밀값을 제거하세요.
- Runner가 실행하는 저장소 코드는 **해당 WSL 사용자 권한으로 실행**됩니다. 신뢰할 수 있는 코드·기여자에게만 배포 권한을 부여하고 Runner 등록 토큰과 비밀값을 보호하세요.

STAGE/PROD/EC2 확장과 관리자 페이지는 이 DEV 프로토타입의 후속 작업입니다.
