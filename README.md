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
