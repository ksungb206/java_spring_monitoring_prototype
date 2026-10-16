# MSA 장애 모니터링 및 서비스 복구 자동화 프로젝트

**Node.js NestJS 기반 프로젝트를 Java 17 / Spring Boot 3.3.5로 전환한 모니터링 및 장애 대응 프로토타입**

Java 17 · Spring Boot 3.3.5 · MyBatis · Maven · Ubuntu / WSL(systemd) · Gmail SMTP

## 빠른 시작 (Quick Start)

Ubuntu 또는 WSL2 Ubuntu에서 Java 17 / Spring Boot 3.3.5 기반 LOCAL 서버를 처음 실행하는 절차입니다. 자세한 환경 설정 및 운영 정책은 아래 기존 가이드를 참고하세요.

### 1. 저장소 Clone 및 브랜치 확인

Swagger가 적용된 기능 브랜치를 내려받습니다.

```bash
git clone -b feat/ksb/local https://github.com/ksungb206/java_spring_monitoring_prototype.git
cd java_spring_monitoring_prototype
git branch --show-current
```

출력 브랜치가 `feat/ksb/local`인지 확인합니다. 기본 `git clone`만 실행하면 기본 브랜치인 `main`이 선택됩니다.

### Git 브랜치 운영 정책 및 현재 적용 상태

이 프로젝트에는 `feat/ksb/local`, `dev`, `stage`, `prod`, `main` 총 5개 브랜치가 있습니다. **원래 설계한 브랜치 운영 정책**과 **현재 프로토타입에서 실제 사용하는 단계**를 구분합니다.

| 브랜치 | 목적 | 기본 실행 환경 | 기본 포트 | 현재 사용 상태 |
| --- | --- | --- | --- | --- |
| `feat/ksb/local` | 신규 기능 개발 및 개인 테스트 | LOCAL | 7001 | 기능 개발에 사용 |
| `dev` | 개발 기능 통합 및 테스트 | DEV | 7002 | 통합 검증 및 자동 배포에 사용 |
| `stage` | 운영 배포 전 최종 테스트 | STAGE | 7003 | 브랜치는 존재하나 배포·검증 단계에 미사용 |
| `prod` | 실제 운영 배포 및 운영 정상 동작 검증 | PROD | 7004 | 브랜치는 존재하나 배포·검증 단계에 미사용 |
| `main` | 전체 검증을 마친 최종 안정 코드 보관 | 특정 실행 환경에 종속되지 않음 | 해당 없음 | 현재 DEV까지 반영된 코드를 기준으로 관리 |

**각 브랜치의 역할**

- **`feat/ksb/local`**: 신규 기능 구현, 수정, Swagger 적용 등 LOCAL 환경에서 먼저 작업하고 검증하는 개인 기능 브랜치입니다. 이 브랜치의 Push만으로 DEV 자동 배포가 실행되지는 않습니다.
- **`dev`**: 기능 브랜치에서 개발한 내용을 통합하고 검증합니다. 현재 GitHub Actions와 self-hosted Runner를 이용한 DEV 자동 배포 대상이며 기본 포트는 `7002`입니다.
- **`stage`**: 원래 정책에서는 DEV 검증 이후 운영 환경과 유사한 조건에서 최종 테스트하는 단계입니다. 현재는 브랜치만 존재하며 실제 STAGE 배포 및 검증 과정에는 사용하지 않습니다.
- **`prod`**: 원래 정책에서는 STAGE 테스트를 통과한 코드를 실제 운영 환경에 배포하고 정상 동작을 검증하는 단계입니다. 현재는 브랜치만 존재하며 실제 PROD 배포 및 검증 과정에는 사용하지 않습니다.
- **`main`**: **원래 정책에서는 PROD까지 모든 단계의 테스트와 정상 동작 검증을 마친 코드를 최종 반영하는 완전 최종 브랜치**입니다. **현재는 STAGE/PROD를 사용하지 않는 프로토타입 단계이므로 DEV까지 검증·반영된 내용을 기준으로 `main`을 관리합니다.** 향후 STAGE/PROD를 실제 사용하게 되면 전체 검증을 완료한 코드만 `main`에 반영하는 정책으로 전환할 예정입니다.

**원래 설계한 브랜치 적용 흐름 (향후 목표)**

```text
feat/ksb/local → dev → stage → prod → main
   기능 개발       통합     최종     운영     완전 최종
                  테스트   테스트   검증     코드 반영
```

**현재 프로토타입의 적용 흐름**

```text
feat/ksb/local → dev → main
   기능 개발       통합     DEV까지 검증·반영된 코드
                  검증
```

현재 자동 배포가 구성된 대상은 `dev`입니다. `stage`와 `prod` 자동 배포 및 실제 환경 검증은 아직 구현·검증된 것으로 간주하지 않습니다. 브랜치 간 병합은 별도 작업이며, 브랜치를 변경하거나 Pull했다고 실행 중인 Spring Boot 서비스가 자동으로 갱신되지는 않습니다.

**현재 브랜치 및 작업 상태 확인**

```bash
git branch --show-current
git status -sb
git branch -a
```

**기능 브랜치 전환 및 최신 코드 받기**

```bash
git fetch origin
git switch feat/ksb/local
git pull origin feat/ksb/local
git log -1 --oneline
```

로컬에 기능 브랜치가 없다면 `git switch --track origin/feat/ksb/local`을 사용합니다. 브랜치 전환 전에 `git status`로 미커밋 변경 사항을 확인하세요.

**수정 사항 커밋 및 푸시 예시 (README를 수정한 경우)**

```bash
git add README.md
git commit -m "README 브랜치 운영 정책 및 현재 적용 상태 정리"
git push origin feat/ksb/local
```

`dev` 브랜치에 Push하면 설정된 GitHub Actions DEV 자동 배포가 실행될 수 있습니다. 기능 개발 및 검증 단계의 병합은 Pull Request와 리뷰를 통해 진행하는 것을 권장합니다.

### 2. 필수 프로그램 및 systemd 준비

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk maven git curl tar python3 sudo
```

WSL2에서는 systemd를 활성화해야 `start:local` 명령을 사용할 수 있습니다. 활성화 방법은 아래 **최초 1회: 각 개발자의 WSL 설정** 절을 참고하세요.

### 3. LOCAL 환경 설정

프로젝트 루트에 `.env.local`을 준비합니다. 파일이 없다면 본인의 환경에 맞게 생성해야 합니다. Gmail 장애 알림을 사용할 때는 다음 항목을 설정합니다.

```dotenv
MAIL_USERNAME=your-sender@gmail.com
MAIL_PASSWORD=your-google-app-password
MONITOR_EMAIL_TO=your-recipient@example.com
MONITORING_EMAIL_ENABLED=true
```

실제 비밀번호는 GitHub에 커밋하지 마세요. 메일 알림을 사용하지 않는다면 `MONITORING_EMAIL_ENABLED=false`로 설정할 수 있습니다.

### 4. Maven 빌드

```bash
mvn clean install
```

출력 마지막에 `BUILD SUCCESS`가 표시되는지 확인합니다.

### 5. LOCAL 서버 시작 및 상태 확인

```bash
source ./scripts/activate.sh
start:local
status:local
```

`start:local`은 프로젝트의 systemd 기반 시작/배포 스크립트입니다. 최초 실행이나 경로 변경 시 서비스 설치 및 Maven 빌드가 다시 수행될 수 있습니다. 새로운 터미널을 열면 `source ./scripts/activate.sh`를 다시 실행해야 합니다.

### 6. Health Check 및 Swagger 확인

```bash
curl http://localhost:7001/api/v1/health
curl http://localhost:7001/v3/api-docs
```

- LOCAL Swagger UI: http://localhost:7001/swagger-ui/index.html
- LOCAL OpenAPI JSON: http://localhost:7001/v3/api-docs
- DEV Swagger UI: http://localhost:7002/swagger-ui/index.html (DEV 서버 배포 및 실행 시)

Swagger는 LOCAL/DEV/STAGE/PROD에서 기본 활성화됩니다. 외부 공개 환경에서는 환경변수로 비활성화하거나 네트워크 접근을 제한하세요. Swagger 문서에 노출된 API라도 Spring Security 정책에 따라 호출이 제한될 수 있습니다.

### 7. 서버 관리 명령어

```bash
stop:local
restart:local
status:local
logs:local
```

### 8. 이미 Clone한 저장소 업데이트

기존 작업 내용이 있다면 `git status`로 확인한 후 최신 브랜치를 받습니다.

```bash
git status
git switch feat/ksb/local
git pull origin feat/ksb/local
```

Git Pull은 소스 코드만 갱신합니다. 실행 중인 서비스에 반영하려면 최신 코드의 빌드와 재배포가 필요하며, 단순 `systemctl start` 또는 `restart:local`만으로는 기존 JAR가 갱신되지 않을 수 있습니다. 배포 방법은 아래 LOCAL 환경 실행 및 systemd 관리 설명을 참고하세요.

---

## DEV 배포 안정성 검증 (feat 브랜치 변경 사항)

현재 `feat/ksb/local`에만 배포 스크립트 변경이 적용되어 있습니다. DEV에서 테스트하려면 코드 검토 후 `dev` 브랜치에 병합해야 합니다. **feat 작업 폴더에서 `bash scripts/deploy-branch.sh dev`를 실행하지 마세요.** 이 스크립트는 `dev` 전용 체크아웃 및 systemd 서비스를 요구합니다.

### 배포 구조

- Maven 빌드와 테스트는 별도 임시 폴더에서 수행합니다. 실행 중인 `target/`을 정리하지 않습니다.
- systemd가 사용하는 실행 파일은 `run/dev/application.jar`입니다. 실제 서비스 설정이 다른 JAR를 가리키면 배포를 **중단**합니다.
- 빌드 성공 후 기존 JAR를 백업하고, 같은 파일시스템의 임시 파일을 통해 새 JAR를 교체합니다.
- 재시작 또는 Health Check 실패 시 이전 JAR로 복구하고 재시작합니다. **무중단 배포는 아닙니다.**
- 동일 환경에서 동시 배포가 실행되지 않도록 `flock` 잠금을 사용합니다.

### DEV 반영 전 사전 점검 (서비스 중단 없음)

DEV 전용 체크아웃에서 아래 명령을 실행합니다. 먼저 `git branch --show-current`가 `dev`인지 확인하세요.

```bash
bash -n scripts/deploy-branch.sh
sudo systemctl cat main-api-dev.service
sudo systemctl show main-api-dev.service -p WorkingDirectory -p ExecStart -p MainPID
curl -i http://localhost:7002/api/v1/health
sha256sum run/dev/application.jar
```

`ExecStart`가 해당 DEV 체크아웃의 `run/dev/application.jar`를 가리켜야 합니다. 다르면 **배포 명령을 실행하지 말고** 기존 systemd 유닛과 실행 JAR를 먼저 안전하게 이전해야 합니다. 기존 DEV가 `target/`을 실행 중인 경우 자동 변경하지 않습니다.

### 검증 시나리오

| 테스트 | 실행 방법 | 합격 기준 |
| --- | --- | --- |
| T1 정상 배포 | dev 브랜치 반영 후 전용 체크아웃에서 `bash scripts/deploy-branch.sh dev` | BUILD_SUCCEEDED, DEPLOY_SUCCEEDED, HTTP 200 |
| T2 컴파일 오류 | 격리 테스트 환경에서 의도적인 Java 문법 오류가 포함된 테스트 커밋을 배포 | BUILD_FAILED, 기존 MainPID와 JAR 체크섬 동일, HTTP 200 |
| T3 단위 테스트 실패 | 격리 테스트 환경에서 실패하는 JUnit 테스트 커밋을 배포 | BUILD_FAILED, 기존 MainPID와 JAR 체크섬 동일, HTTP 200 |
| T4 신규 JAR 시작 실패 | DEV와 분리된 테스트 서비스에서 신규 빌드에만 시작 오류 주입 | DEPLOY_FAILED 및 ROLLBACK succeeded, 이전 버전 HTTP 200 |
| T5 Health 실패 | DEV와 분리된 테스트 서비스에서 신규 버전 Health 실패 주입 | DEPLOY_FAILED 및 ROLLBACK succeeded, 이전 버전 HTTP 200 |

T2~T5는 테스트 커밋을 실제 `dev`에 푸시하면 자동 배포가 실행될 수 있으므로 **현재 정상 DEV에서 곧바로 실험하지 마세요.** 별도 격리 환경과 테스트 브랜치를 준비한 후 실행해야 합니다. 실패 주입용 자동 테스트 도구는 아직 추가하지 않았습니다.

테스트 전후에 아래 명령으로 PID, JAR 체크섬, HTTP 응답을 비교합니다.

```bash
sudo systemctl show main-api-dev.service -p MainPID
sha256sum run/dev/application.jar
curl -i http://localhost:7002/api/v1/health
ls -lt logs/dev/deployment/
```

**한계:** 현재 Health Check는 HTTP 성공 여부만 확인합니다. 새 빌드의 Git SHA까지 일치하는지 검증하는 기능은 다음 개선 과제입니다.

---

## 1. 프로젝트 목적과 출발점

본 프로젝트는 기존 Node.js NestJS 기반 프로젝트를 Java Spring Boot로 컨버팅한 버전이다. 프레임워크 전환을 출발점으로 MSA 서비스의 연결 장애를 감지하고, 장애 발생 사실을 운영자에게 알리며, 서버별 복구 시나리오를 검증하기 위한 포트폴리오용 프로토타입이다.

**모니터링 서버와 개별 MSA 서버의 책임은 구분한다.** 모니터링 서버는 대상 서비스의 TCP 연결 상태 감지와 장애 이메일 통지를 담당한다. 자동 복구 시도, 정상화 확인, 복구 이력 기록 및 결과 알림은 향후 Main/OAuth/Log/Socket 등 **각 서버별 시나리오**로 적용한다. 현재 LOCAL 배포 복구 기능을 모든 MSA 서버에 이미 적용한 것은 아니다.

### 자체 자동 배포 기능을 구현한 이유

Jenkins와 같은 검증된 CI/CD 도구가 있지만, 인프라 제약이나 운영 환경의 문제로 외부 배포 시스템을 사용할 수 없는 상황도 고려했다. 이에 특정 배포 도구에 전적으로 의존하지 않고, 프로젝트 내부의 스크립트와 서비스 관리 기능을 이용해 빌드, 배포, Health Check, 실패 시 롤백을 수행할 수 있도록 설계했다.

현재 구현은 Jenkins를 대체하는 완성형 배포 플랫폼이 아니다. 배포 승인, 권한 관리, 이력 관리, 다양한 환경 지원 등 보완할 요소가 많다. 장기적으로 기능을 개선하고 확장하여 **이 프로젝트에 적합한 자체 배포 자동화 시스템**으로 발전시키는 것이 목표다. 현재 DEV 자동 배포에는 GitHub Actions와 self-hosted Runner를 활용하며, 자체 배포 스크립트는 실제 배포 절차를 수행한다.

### 자체 자동 복구 기능을 구현한 이유

서드파티 도구나 라이브러리로 장애 대응을 구성할 수도 있지만, 특정 환경에서 해당 도구를 도입하거나 사용하기 어려운 경우를 대비하고자 했다. 서버별 장애 유형과 운영 조건에 따라 개발자가 복구 절차를 직접 수정하고 확장할 수 있도록 **커스터마이징 가능한 복구 구조**를 지향한다.

현재 LOCAL 환경에서는 systemd 기반 프로세스 재시작과 배포 실패 시 이전 JAR 롤백을 구현했다. 다만 프로세스가 살아 있는 상태의 무응답 장애, 모든 MSA 서버에 대한 자동 복구, 완전한 무중단 운영까지 보장하는 단계는 아니다. 향후 서버별 Health Check와 장애 판정, 복구 정책을 고도화할 계획이다.

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

## 5. 검증 결과, 주요 이슈 및 해결 방향

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
| MAIN 서버 TCP 장애 감지 및 Gmail 알림 | **성공**: `SERVER_UNREACHABLE name=main host=127.0.0.1 port=7191` 기록, `EMAIL_ALERT_SENT target=main recipients=1` 기록, 사용자 Gmail 실제 수신 확인, 모니터링 서비스 `active` 유지 | 각 MSA 서버의 자동 복구는 서버별 systemd 및 Health Check 구성에 따라 수행 |

마지막 LOCAL 테스트에서 `main-api-local.service`는 정상 실행 중이었고 `/api/v1/health`가 HTTP 200을 반환했다. MAIN 장애 감지 당시에도 서비스 상태는 `active`였다. 장애 메일은 첫 연결 실패 시 발송하며 같은 장애가 지속되는 동안 매 검사마다 재발송하지 않는다. 단, 모니터링 서버 재시작 시 이전 상태가 초기화되므로 장애 메일이 다시 발송될 수 있다. **실제 신규 JAR 실행 실패 후 자동 롤백 성공은 아직 미검증**이다.

### 향후 개선 및 개발 예정 사항

아래 항목은 **현재 구현 완료 기능이 아니라 향후 개발 과제**다. 장애 감지와 일부 배포·롤백 기능이 동작하더라도 전체 운영 환경에서 자동 복구가 보장되는 것은 아니다.

| 우선순위 | 개선 항목 | 현황 및 개선 계획 | 완료 판단 기준 |
| --- | --- | --- | --- |
| 1 | DEV 배포 중 실행 JAR 보호 | LOCAL은 격리 디렉터리에서 빌드하지만 DEV의 `deploy-branch.sh`는 실행 JAR가 위치할 수 있는 `target/`에서 `mvn clean package`를 수행한다. 빌드 경로와 실행·배포 경로를 분리하고 새 JAR를 안전하게 교체하도록 개선 | 실행 중 빌드 실패에도 기존 프로세스가 정상 동작하고, 배포 실패 시 이전 JAR로 복구되는 테스트 통과 |
| 2 | API 무응답 시 자동 복구 | systemd의 `Restart=on-failure`는 프로세스 비정상 종료에 대응하지만, 프로세스가 살아 있는 상태의 API 무응답을 복구하지 못할 수 있다. 서버별 HTTP Health Check, 연속 실패 판정, 재시작 및 복구 후 재검증 정책 추가 | 프로세스 생존·API 무응답 장애를 주입하여 감지, 제한된 복구 시도, 정상화 확인 |
| 3 | 배포 Health Check 정확성 강화 | DEV 배포 스크립트의 고정 포트와 환경별 `.env` 설정을 일치시키고, 단순 HTTP 성공뿐 아니라 실제 배포 대상 프로세스와 버전/빌드 식별자를 검증 | 다른 프로세스가 같은 포트에서 응답하거나 환경 포트가 바뀌어도 잘못된 배포 성공 판정 방지 |
| 4 | 자체 자동 배포의 독립성 확대 | 현재 DEV Push 트리거는 GitHub Actions 및 self-hosted Runner에 의존한다. 외부 CI/CD 사용이 어려운 환경에서도 동작할 자체 트리거, 실행 작업 관리, 승인·권한·배포 이력 관리 기능을 단계적으로 개발 | GitHub Actions 없이도 승인된 배포 요청을 실행하고 진행 상태 및 결과를 추적 |
| 5 | 운영 복구 정책 및 상태 관리 | 재시작 횟수·간격 제한, 반복 장애 시 알림 정책, 장애 상태 영속화, 재부팅 후 서비스 자동 시작 여부를 환경별로 설계하고 검증 | 반복 장애에서 무한 재시작·중복 알림을 제어하고, 서비스 재시작 및 호스트 재부팅 후에도 정책대로 동작 |

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

### 서버 시작 시 sudo 비밀번호 입력 안내

`start:local`, `start:dev`, `start:stage`, `start:prod` 명령을 실행할 때 systemd 서비스 설치·관리 등 관리자 권한이 필요한 작업에서는 다음과 같이 `sudo` 비밀번호를 요청할 수 있습니다.

```text
[sudo] password for 사용자명:
```

**여기에 입력할 비밀번호는 현재 명령어를 실행 중인 WSL Ubuntu 사용자 계정의 비밀번호입니다.** Ubuntu에서 `sudo` 권한을 확인하기 위한 것이며 Windows 로그인 비밀번호, GitHub 계정 비밀번호 또는 Gmail 앱 비밀번호가 아닙니다.

- 비밀번호 입력 시 화면에 글자나 `*`가 표시되지 않아도 정상입니다. 입력한 뒤 Enter 키를 누르세요.
- 사용자 계정에 `sudo` 권한이 없거나 비밀번호가 맞지 않으면 관리자 권한이 필요한 작업이 실패할 수 있습니다.
- Ubuntu 사용자 비밀번호를 잊어버렸다면 해당 WSL 배포판의 계정 비밀번호를 재설정해야 합니다.
- 실제 비밀번호를 README, 소스 코드, GitHub 또는 공유 로그에 기록하지 마세요.
- `.env.local`의 `MAIL_PASSWORD`는 메일 알림에 사용하는 **Gmail 앱 비밀번호**이며, 여기서 입력하는 Ubuntu `sudo` 비밀번호와는 다릅니다.

위 안내는 LOCAL뿐 아니라 DEV/STAGE/PROD 명령어에서 `sudo` 비밀번호를 요청하는 경우에도 동일하게 적용됩니다. 단, 이미 권한이 허용되었거나 `sudo` 인증이 유지 중이면 비밀번호 입력 화면이 나타나지 않을 수 있습니다.

### Swagger 환경별 접근 및 403 대응

Swagger/OpenAPI는 LOCAL(7001), DEV(7002), STAGE(7003), PROD(7004) 프로필에서 동일한 경로로 제공하도록 설정합니다. Spring Security는 `/swagger-ui/**`, `/swagger-ui.html`, `/v3/api-docs/**` 경로를 허용하며, 나머지 API의 기존 접근 제한은 유지합니다.

| 환경 | Swagger UI | OpenAPI JSON |
| --- | --- | --- |
| LOCAL | http://localhost:7001/swagger-ui/index.html | http://localhost:7001/v3/api-docs |
| DEV | http://localhost:7002/swagger-ui/index.html | http://localhost:7002/v3/api-docs |
| STAGE | http://localhost:7003/swagger-ui/index.html | http://localhost:7003/v3/api-docs |
| PROD | http://localhost:7004/swagger-ui/index.html | http://localhost:7004/v3/api-docs |

**보안 주의:** STAGE/PROD에도 문서가 노출되므로 외부 공개 환경에서는 네트워크 접근 제어를 적용하거나 `SPRINGDOC_API_DOCS_ENABLED=false`, `SPRINGDOC_SWAGGER_UI_ENABLED=false`로 비활성화하세요. 비활성화 시 Swagger는 제공되지 않습니다.

**중요:** 이 설정은 현재 `feat/ksb/local` 브랜치에만 적용됩니다. `dev`, `stage`, `prod`, `main` 브랜치에도 반영하려면 변경 사항을 해당 브랜치에 병합하고 **새로 빌드·배포**해야 합니다. 기존 DEV 서버의 403은 구버전 Spring Security 설정에서 발생할 수 있으며, 기능 브랜치만 수정해도 기존 서버가 자동으로 바뀌지는 않습니다.

```bash
curl -i http://localhost:7002/swagger-ui/index.html
curl -i http://localhost:7002/v3/api-docs
```

HTTP 403이면 실행 중인 서버의 배포 버전과 Spring Security 설정을 확인하고, 404이면 Swagger 의존성·활성화 설정 및 프로필을 확인하세요.

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

### GitHub Actions 웹 설정 가이드 (최초 1회)

아래는 **새로운 개발자나 서버를 추가할 때 참고하는 설정 절차**다. 이미 GitHub Actions 및 Runner를 설정한 개발자는 다시 등록하지 말고, 다음의 설정값과 실행 상태만 확인한다.

1. GitHub 저장소의 **Settings → Actions → General**에서 Actions 실행이 허용되어 있는지 확인한다. 저장소 정책상 실행이 제한된 경우 관리자 권한이 필요할 수 있다.
2. **Settings → Environments**에서 이름이 정확히 `dev`인 Environment를 생성하거나 기존 설정을 연다. **Environment variables**에 `DEPLOY_ROOT`를 추가한다. 값은 Runner가 실행되는 WSL 내부 DEV 체크아웃의 **절대 경로**(예: `/home/<WSL사용자>/deploy-checkouts/dev`)다. 실제 설치 경로가 기본값 `$HOME/deploy-checkouts/dev`라면 워크플로가 그 기본값을 사용하므로 변수는 생략할 수도 있다.
3. **Settings → Actions → Runners**에서 해당 WSL의 self-hosted Runner가 `Online`인지, 라벨에 `self-hosted`, `linux`, `deploy-dev`가 포함되어 있는지 확인한다. 신규 설치할 때만 **New self-hosted runner**에서 Linux용 등록 토큰을 발급한다. 토큰은 공유하거나 저장소에 커밋하지 않는다.
4. 저장소의 `.github/workflows/deploy.yml`이 **원격 `dev` 브랜치에도 존재**해야 한다. 현재 워크플로는 `dev` Push 시 실행되며, **Actions → Deploy monitoring server**에서 실행 이력과 Job 로그를 확인할 수 있다. `workflow_dispatch`를 사용한 수동 실행도 `dev` 브랜치를 선택해야 한다.
5. **Actions** 탭에서 Job이 `queued`라면 Runner 온라인 여부와 라벨, Environment 승인 대기 여부를 확인한다. `Success`로 끝났더라도 실제 WSL에서 `curl -fsS http://localhost:7002/api/v1/health`로 서버 응답을 별도 검증한다.

**설정 시 주의:** GitHub Actions는 배포 요청을 전달하고, 실제 빌드·재시작·검증은 self-hosted Runner가 있는 WSL에서 실행한다. WSL이 종료된 상태에서는 작업이 대기할 수 있다. 현재 구성은 **한 번의 Job을 한 대의 Runner에서 실행**하므로 같은 라벨의 모든 개발자 PC에 동시 배포하는 방식이 아니다. Runner를 여러 개 설치하거나 기존 Runner를 교체하기 전에 현재 설정을 확인한다.

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


### 장애 사례: 2026-10-17 DEV 자동 배포 sudo 인증 실패 및 API 검증

**환경:** GitHub Actions Self-hosted Runner (WSL, 사용자 user), DEV 브랜치, main-api-dev.service, scripts/deploy-branch.sh.

**증상:** Git 동기화 후 Deploy DEV to the runner's own WSL 단계에서 실패했습니다.

~~~text
Already up to date.
sudo: interactive authentication is required
Error: Process completed with exit code 1.
~~~

**원인 조사:** Git 작업 트리에는 추적 파일 변경이 없었고 Fast-forward 가능 여부 검사 종료 코드는 0이었습니다. systemd WorkingDirectory와 ExecStart의 JAR 경로도 정상입니다. 배포 스크립트에서 다음 명령을 실행하고 있었습니다.

~~~bash
UNIT_EXEC="$(sudo -n systemctl show "$UNIT" -p ExecStart --value)"
~~~

확인 당시 sudoers의 NOPASSWD 목록에는 systemctl cat, systemctl restart, systemctl show -p WorkingDirectory 명령이 있었으나 ExecStart 조회는 없었습니다. 비대화형 Runner에서는 sudo 인증을 입력할 수 없으므로 이 명령이 최초 실패의 유력한 원인입니다.

**조치:** sudo 없이 ExecStart를 조회할 수 있음을 확인하고 다음과 같이 수정하여 dev 브랜치에 반영했습니다.

~~~bash
# 변경 전
UNIT_EXEC="$(sudo -n systemctl show "$UNIT" -p ExecStart --value)"
# 변경 후
UNIT_EXEC="$(systemctl show "$UNIT" -p ExecStart --value)"
~~~

**추가 점검:** 코드 수정 후 첫 배포에서도 같은 sudo 인증 오류가 발생했습니다. sudo -n -k 옵션으로 systemctl cat 및 WorkingDirectory 조회가 비밀번호 없이 실행됨을 확인했고, Runner 실행 계정도 user로 확인했습니다. 동일 커밋의 실패한 Job을 다시 실행했습니다.

~~~bash
gh run rerun 38978979869 --failed --repo ksungb206/java_spring_monitoring_prototype
gh run watch 38978979869 --repo ksungb206/java_spring_monitoring_prototype --exit-status
~~~

최종 결과:

~~~text
Run Deploy monitoring server (38978979869) has already completed with 'success'
~~~

**최종 API 응답 확인:** DEV Health API (GET http://127.0.0.1:7002/api/v1/health)의 응답 본문은 다음과 같았습니다.

~~~json
{
  "code": 200,
  "message": "success",
  "data": {
    "status": "result_ok_deploy_v2",
    "timestamp": "2026-10-16T23:03:40.950226225Z"
  }
}
~~~

**최종 결과: GitHub Actions 자동 배포 성공 및 Spring Boot Health API 성공 응답 본문 확인.** 위 code: 200은 JSON 본문의 애플리케이션 코드이며, 별도의 HTTP 상태줄이나 전체 기능 테스트를 검증한 것은 아닙니다.

**미확정 사항:** 코드 수정 직후 첫 실행은 실패했으나 동일 커밋 재실행은 성공했습니다. 그 차이의 정확한 원인은 확인되지 않았으므로 단정하지 않습니다.

**재발 방지:** 읽기 전용 systemctl 조회에는 불필요한 sudo를 사용하지 않습니다. 서비스 재시작처럼 권한이 필요한 작업에만 최소 범위의 NOPASSWD 권한을 적용하고, 배포 초기 단계의 오류 로그를 보강하며, 배포 완료 후 Health API를 확인합니다.

- [최초 실패 실행 #38967367425](https://github.com/ksungb206/java_spring_monitoring_prototype/actions/runs/38967367425)
- [수정 후 실패 및 재실행 성공 #38978979869](https://github.com/ksungb206/java_spring_monitoring_prototype/actions/runs/38978979869)
