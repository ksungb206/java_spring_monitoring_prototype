# MSA 모니터링 서버

Java 17 · Spring Boot 3.3.5 · MyBatis · Maven · Ubuntu / WSL(systemd)

MSA 서비스의 TCP 연결 상태를 확인하고 장애를 Gmail로 알립니다. 모니터링 서버가 정상 종료되면 종료 알림을 전송하고, 비정상 종료는 systemd의 종료 후처리 스크립트가 별도로 이메일 전송을 시도합니다.

> **현재 검사 대상:** OAuth(7192), Log(7193), Socket(7194). Main(7191)은 현재 모니터링 대상에 포함되지 않습니다. 대상 서버의 HTTP 응답 내용이 아닌 **TCP 연결 성공 여부**를 확인합니다.

## 1. 환경별 설정 파일

`.example` 파일을 사용하지 않습니다. 프로젝트 ZIP에는 아래 네 파일이 있으며 각 파일 상단에 **환경의 목적과 설정 변수 설명**을 적었습니다.

| 파일 | 용도 | 기본 포트 | 실행 명령 |
| --- | --- | --- | --- |
| `.env.local` | 개인 PC, WSL에서 로컬 개발과 메일 기능 확인 | 7001 | `start:local` |
| `.env.dev` | 개발 서버에서 기능 통합 테스트 | 7002 | `start:dev` |
| `.env.stage` | 운영 배포 전 사전 검증 | 7003 | `start:stage` |
| `.env.prod` | 운영 서버에서 실제 MSA 상태 감시 | 7004 | `start:prod` |

각 파일에서 `MONITOR_OAUTH_HOST`, `MONITOR_LOG_HOST`, `MONITOR_SOCKET_HOST` 및 대응 포트를 실제 서버 주소에 맞게 변경하세요. 프로필마다 발신자, 수신자, 검사 주기 등을 독립적으로 설정할 수 있습니다.

**주의:** 이 ZIP의 `.env.*` 파일에는 예시 Gmail 계정과 비밀번호만 들어 있습니다. 실제 Gmail 앱 비밀번호를 채워 넣은 `.env.*`는 `.gitignore`에 의해 Git 추적에서 제외됩니다. 따라서 **ZIP에는 설정 파일이 포함되지만 GitHub에서 새로 clone한 저장소에는 해당 파일이 없을 수 있습니다.** Git 배포 시에는 비밀정보를 제외한 설정 파일을 안전하게 배포하는 방식(배포 시스템의 secret 주입 등)을 별도로 마련해야 합니다. 실제 비밀번호를 GitHub에 올리지 마세요.

## 2. 준비 및 빌드

Ubuntu 또는 WSL Ubuntu에서 systemd를 사용합니다. JDK 17, Maven, Python 3가 필요합니다. Maven은 프로젝트 의존성을 내려받지만 JDK나 Maven 프로그램 자체를 설치하지는 않습니다.

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk maven python3
cd /path/to/main_api_spring_mybatis
mvn clean install
```

`BUILD SUCCESS`가 표시되면 빌드 성공입니다. 빌드 중 권한 문제가 생기면 해당 경로의 쓰기 권한을 확인하세요.

## 3. local 환경 실행

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

## 4. 메일 설정

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

## 5. 장애 및 종료 이메일 검증

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

## 6. 프로젝트 구성

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

## 7. 운영 주의사항

- 비밀정보가 포함된 `.env.*`는 Git에 커밋하지 마세요. `git status --short` 및 `git ls-files`로 추적 여부를 확인하세요.
- `start:<환경>` 명령은 systemd를 사용하므로 `systemd`가 PID 1로 실행되어야 합니다.
- 이 ZIP은 모니터링 서버 프로젝트이며, 실제 OAuth/Log/Socket MSA 서버의 구현은 포함하지 않습니다.
- 환경별 메일 발송과 비정상 종료 처리는 배포할 서버에서 직접 검증해야 합니다.

## 8. DEV 자동 배포 (GitHub Actions + 로컬 WSL)

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
