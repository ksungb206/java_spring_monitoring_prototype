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
| `scripts/service-start.sh`, `scripts/service-exit.sh` | 서비스 시작/종료 후처리 |
| `scripts/abnormal-exit-email.py` | 비정상 종료 후 이메일 전송 시도 |
| `.env.local`, `.env.dev`, `.env.stage`, `.env.prod` | 환경별 설정 파일 |

## 7. 운영 주의사항

- 비밀정보가 포함된 `.env.*`는 Git에 커밋하지 마세요. `git status --short` 및 `git ls-files`로 추적 여부를 확인하세요.
- `start:<환경>` 명령은 systemd를 사용하므로 `systemd`가 PID 1로 실행되어야 합니다.
- 이 ZIP은 모니터링 서버 프로젝트이며, 실제 OAuth/Log/Socket MSA 서버의 구현은 포함하지 않습니다.
- 환경별 메일 발송과 비정상 종료 처리는 배포할 서버에서 직접 검증해야 합니다.

## 8. 브랜치 기반 CI/CD 자동 배포

GitHub Actions 워크플로 `.github/workflows/deploy.yml`은 원격 `dev`, `stage`, `prod` 브랜치에 **Push가 발생하면** 해당 환경의 배포 작업을 시작합니다. 피처 브랜치에서 작업하거나 로컬에서 Merge하는 것만으로는 원격 배포가 시작되지 않습니다. 대상 환경 브랜치에 병합한 뒤 그 결과를 원격 브랜치에 Push해야 합니다.

권장 흐름:

1. 개발자가 저장소를 clone하고 `feat/개발자명/기능명` 같은 피처 브랜치에서 작업합니다.
2. 변경 사항을 Push하고 Pull Request를 통해 대상 브랜치로 병합합니다.
3. 병합 결과를 원격 `dev`, `stage` 또는 `prod` 브랜치에 Push합니다.
4. GitHub Actions가 해당 환경의 배포 작업을 실행합니다.
5. Runner에서 Maven 빌드·테스트 후 systemd 서비스를 재시작하고 헬스체크를 수행합니다.

### GitHub Environment 변수: DEPLOY_ROOT

워크플로는 GitHub Environment 이름을 브랜치명(`dev`, `stage`, `prod`)으로 사용하고, 해당 Environment의 **Variables**에서 `DEPLOY_ROOT`를 읽습니다. 각 Environment에서 다음 변수를 별도로 등록해야 합니다.

| Environment | 변수 이름 | 값 |
| --- | --- | --- |
| `dev` | `DEPLOY_ROOT` | DEV 배포 체크아웃이 있는 Runner 로컬 절대 경로 |
| `stage` | `DEPLOY_ROOT` | STAGE 배포 체크아웃이 있는 Runner 로컬 절대 경로 |
| `prod` | `DEPLOY_ROOT` | PROD 배포 체크아웃이 있는 Runner 로컬 절대 경로 |

GitHub 저장소의 **Settings → Environments → 해당 환경 → Environment variables → Add environment variable**에서 `DEPLOY_ROOT`를 추가합니다. 변수명은 대소문자를 포함해 정확히 `DEPLOY_ROOT`여야 합니다. 워크플로는 `${{ vars.DEPLOY_ROOT }}`를 사용하므로 이를 Actions Secret에만 등록하면 읽히지 않습니다.

**경로는 개발자 PC의 경로가 아니라 self-hosted Runner가 실행되는 컴퓨터에서 실제로 접근할 수 있는 배포 체크아웃 경로여야 합니다.** 예를 들어 현재 WSL 테스트 환경의 경로가 `/mnt/d/main_api_spring_mybatis_COMPLETE/main_api_spring_mybatis`라면 그 경로는 현재 컴퓨터의 WSL에서만 유효합니다. 다른 컴퓨터에서 실행되는 Runner에는 그 컴퓨터의 실제 경로를 설정해야 합니다. `DEPLOY_ROOT` 아래에는 `.git` 디렉터리와 `scripts/deploy-branch.sh`가 있어야 합니다.

### Self-hosted Runner 요구사항

- GitHub 저장소의 Settings → Actions → Runners에서 연결된 Linux Runner가 있어야 합니다.
- Runner에는 `self-hosted`, `linux`, `deploy-local` 라벨이 필요합니다. 워크플로는 이 라벨 조합을 가진 Runner를 선택합니다.
- Runner 계정은 저장소 체크아웃 경로, JDK 17, Maven, Git, curl 및 systemd에 접근할 수 있어야 합니다.
- 배포 스크립트는 `main-api-dev.service`, `main-api-stage.service`, `main-api-prod.service`를 대상으로 하며, 해당 systemd 유닛과 비밀번호 입력 없이 실행 가능한 최소 권한의 `sudo` 설정이 사전에 필요합니다.
- 각 배포 체크아웃에는 해당 환경의 `.env.dev`, `.env.stage` 또는 `.env.prod`가 안전하게 준비되어 있어야 합니다. `.env.*` 파일이나 비밀값을 Git에 커밋하지 마세요.

### 배포가 실패할 때

- `Configure DEPLOY_ROOT separately for dev, stage, prod GitHub Environments`: 해당 Environment의 Variables에 `DEPLOY_ROOT`가 없거나 이름이 틀렸습니다.
- `Missing Git checkout`: `DEPLOY_ROOT` 경로가 Runner 컴퓨터에 없거나 그 아래에 `.git`이 없습니다.
- `Missing .env.dev` 등: 해당 환경의 비밀 설정 파일이 배포 체크아웃에 없습니다.
- `Expected checked-out branch dev` 등: 배포 체크아웃이 대상 환경 브랜치를 가리키지 않습니다.
- 헬스체크 실패: 애플리케이션 시작 로그, 환경변수, 포트 및 systemd 서비스 상태를 확인하세요.

첫 검증은 `dev` 환경에서 수행하고 성공한 뒤 `stage`, `prod`로 진행하세요. 운영 브랜치에는 GitHub Branch protection/ruleset과 Pull Request 승인 규칙을 설정해 직접 Push 권한을 제한하는 것을 권장합니다.

