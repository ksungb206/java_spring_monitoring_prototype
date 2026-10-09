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

## 8. 브랜치 기반 CI/CD 자동 배포

GitHub Actions 워크플로 `.github/workflows/deploy.yml`은 원격 `dev`, `stage`, `prod` 브랜치에 Push가 발생하면 해당 환경의 배포 작업을 시작합니다. 피처 브랜치에서 작업하거나 로컬에서 Merge하는 것만으로는 배포되지 않습니다. 대상 환경 브랜치에 병합한 뒤 그 결과를 원격 브랜치에 Push해야 합니다.

### 배포 체크아웃은 개발 작업 폴더와 분리

개발자가 작업하는 체크아웃(예: `feat/ksb/local`)을 배포에 직접 사용하지 않습니다. 각 환경은 독립된 디렉터리와 Git 체크아웃을 사용합니다.

| 환경 | 배포 체크아웃 예시 | systemd 서비스 | 포트 |
| --- | --- | --- | --- |
| DEV | `/home/user/deploy-checkouts/dev` | `main-api-dev.service` | 7002 |
| STAGE | `/home/user/deploy-checkouts/stage` | `main-api-stage.service` | 7003 |
| PROD | `/home/user/deploy-checkouts/prod` | `main-api-prod.service` | 7004 |

경로는 예시입니다. `DEPLOY_BASE_DIR`를 지정하면 원하는 WSL 경로를 사용할 수 있습니다. GitHub Actions Runner가 실행되는 컴퓨터에서 접근 가능한 절대 경로를 사용하세요. 개발 작업 폴더의 경로를 세 환경에 공통으로 넣지 마세요.

### 배포 체크아웃 준비 (WSL)

먼저 개발 작업 중인 저장소 루트에서 다음 명령을 실행합니다. 기본 동작은 DEV 체크아웃만 준비하며, 기존 환경 설정 파일은 덮어쓰지 않습니다.

```bash
cd /mnt/d/main_api_spring_mybatis_COMPLETE/main_api_spring_mybatis
bash scripts/setup-deploy-checkouts.sh dev
```

스크립트는 `$HOME/deploy-checkouts/dev`에 `dev` 브랜치를 별도로 clone하거나 기존의 깨끗한 체크아웃을 fast-forward하고, 원본 작업 폴더의 `.env.dev`를 새 체크아웃에 **파일이 없을 때만** 복사합니다. 복사한 환경 파일은 소유자만 읽고 쓸 수 있도록 설정합니다. 기존 `.env.dev`가 있으면 덮어쓰지 않으므로 현재 환경 설정을 보존할 수 있습니다.

체크아웃을 준비한 다음 환경 파일을 로컬에서 확인합니다. 값이나 비밀번호를 채팅, 로그, GitHub에 붙여 넣지 마세요.

```bash
ls -la "$HOME/deploy-checkouts/dev/.env.dev"
```

### DEV systemd 유닛을 새 경로로 설치

현재 `main-api-dev.service`가 개발 작업 폴더를 가리키고 있다면, 배포 체크아웃의 경로로 유닛을 다시 설치해야 합니다. 다음 명령은 Maven 빌드 후 systemd 유닛 파일을 설치/갱신하지만 **서비스를 시작하지는 않습니다**.

```bash
bash "$HOME/deploy-checkouts/dev/scripts/systemd-manager.sh" install dev
sudo -n systemctl show main-api-dev.service -p WorkingDirectory --value
```

두 번째 명령의 경로가 `/home/user/deploy-checkouts/dev`와 일치하는지 확인하세요. `main-api-dev.service`가 이 경로를 가리키기 전에는 자동 배포를 테스트하지 마세요.

### GitHub Environment 변수 설정

GitHub 저장소의 **Settings → Environments → 해당 환경 → Environment variables**에서 각 환경에 `DEPLOY_ROOT`를 별도로 등록합니다. 워크플로는 `${{ vars.DEPLOY_ROOT }}`를 사용하므로 Actions Secret에만 등록하면 읽히지 않습니다.

| GitHub Environment | 변수 이름 | 예시 값 |
| --- | --- | --- |
| `dev` | `DEPLOY_ROOT` | `/home/user/deploy-checkouts/dev` |
| `stage` | `DEPLOY_ROOT` | `/home/user/deploy-checkouts/stage` |
| `prod` | `DEPLOY_ROOT` | `/home/user/deploy-checkouts/prod` |

현재 `dev`의 `DEPLOY_ROOT`가 개발 작업 폴더로 지정되어 있다면 DEV 체크아웃 준비와 systemd 유닛 확인 후 위의 분리된 경로로 바꾸세요. STAGE/PROD는 해당 체크아웃, `.env`, systemd 유닛을 준비하기 전까지 배포 대상으로 사용하지 마세요.

### STAGE / PROD 준비

DEV 배포가 성공하고 동작을 검증한 뒤 각 체크아웃을 별도로 준비합니다.

```bash
bash scripts/setup-deploy-checkouts.sh stage
bash scripts/setup-deploy-checkouts.sh prod
```

각각의 systemd 유닛은 해당 환경의 체크아웃에서 설치해야 합니다.

```bash
bash "$HOME/deploy-checkouts/stage/scripts/systemd-manager.sh" install stage
bash "$HOME/deploy-checkouts/prod/scripts/systemd-manager.sh" install prod
```

설치 전 실제 운영 설정, 메일 수신 대상, 포트 및 배포 승인 절차를 검토하세요. 이 명령은 유닛을 설치하고 빌드하지만 서비스를 시작하지 않습니다. STAGE/PROD 유닛이 존재하지 않거나 `WorkingDirectory`가 해당 체크아웃과 다르면 배포 스크립트는 중단됩니다.

### 배포 스크립트가 수행하는 검사

- 대상 환경과 같은 브랜치인지, 추적 중인 파일에 로컬 수정이 없는지 검사합니다.
- 원격 환경 브랜치를 fetch하고 fast-forward merge만 허용합니다.
- Maven 빌드와 테스트가 성공한 다음에만 systemd 서비스를 재시작합니다.
- 빌드 실패 시 이전 JAR이 있으면 복원하고 서비스를 재시작하지 않습니다.
- 헬스체크 실패 시 이전 JAR 복원 및 재시작을 시도합니다. 이 복구가 모든 장애 상황에서 성공한다고 보장되지는 않으므로 배포 후 로그와 서비스 상태를 확인해야 합니다.
- systemd 유닛의 `WorkingDirectory`가 해당 배포 체크아웃 경로와 일치하지 않으면 중단합니다.

### Self-hosted Runner 요구사항

- GitHub 저장소의 Settings → Actions → Runners에서 Linux Runner가 연결되어 있어야 합니다.
- Runner에는 `self-hosted`, `linux`, `deploy-local` 라벨이 필요합니다.
- Runner 계정에는 저장소 체크아웃, JDK 17, Maven, Git, curl 및 필요한 systemd 명령을 실행할 권한이 있어야 합니다.
- 각 환경의 `.env.dev`, `.env.stage`, `.env.prod`는 배포 체크아웃에 안전하게 준비되어야 합니다. 실제 비밀값을 Git에 커밋하지 마세요.

### 배포 실패 시

- `Configure DEPLOY_ROOT separately...`: 해당 GitHub Environment의 Variables에 `DEPLOY_ROOT`가 없거나 이름이 틀렸습니다.
- `Missing isolated Git checkout`: `DEPLOY_ROOT`가 새 배포 체크아웃을 가리키지 않거나 아직 준비되지 않았습니다.
- `Missing .env.dev` 등: 해당 환경의 설정 파일이 없습니다.
- `Expected checked-out branch dev` 등: 배포 체크아웃이 대상 브랜치가 아닙니다.
- `WorkingDirectory mismatch`: 해당 systemd 유닛을 올바른 환경 체크아웃에서 다시 설치해야 합니다.
- 헬스체크 실패: `sudo journalctl -u main-api-dev.service -n 150 --no-pager`로 로그를 확인하고 환경 설정, 포트, 실제 health endpoint를 점검하세요.

첫 검증은 DEV에서만 수행하세요. DEV 체크아웃, `.env.dev`, systemd 유닛, GitHub `DEPLOY_ROOT`를 모두 확인하기 전에는 변경 사항을 `dev`에 병합해 배포를 트리거하지 않는 것이 안전합니다. 운영 브랜치에는 Branch protection/ruleset과 Pull Request 승인 규칙을 권장합니다.
