# 신규 EC2 환경별 Runner 초기 설치

DEV, STAGE, PROD는 **서로 다른 EC2**에서 실행합니다. 각 서버는 해당 브랜치 하나만 clone하고, 전용 self-hosted Runner를 systemd 서비스로 등록합니다. local 및 feat/*는 설치 대상이 아닙니다.

## 준비

- Ubuntu/systemd, Git, curl, tar, Python 3, Java 17, Maven, sudo, visudo
- 비공개 저장소 clone을 위한 서버별 읽기 권한(예: 읽기 전용 Deploy Key)
- 서버에 안전하게 전달한 환경 설정 파일(`.env.dev` 등)
- GitHub 저장소 Settings → Actions → Runners에서 발급한 단기 Runner 등록 토큰
- 설치 사용자에게 sudo 권한

## 최초 설치 (DEV 예시)

```bash
export ENV_FILE_SOURCE="$HOME/secrets/.env.dev"
read -rsp 'Runner registration token: ' GITHUB_RUNNER_TOKEN; echo
export GITHUB_RUNNER_TOKEN
curl -fsSL https://raw.githubusercontent.com/ksungb206/java_spring_monitoring_prototype/dev/scripts/bootstrap-server.sh -o /tmp/bootstrap-server.sh
# 실행 전 파일 내용을 검토하세요.
bash /tmp/bootstrap-server.sh dev
unset GITHUB_RUNNER_TOKEN
```

위 URL은 본 기능이 dev에 병합된 이후에만 유효합니다. STAGE/PROD는 해당 환경 브랜치 URL과 인자를 사용하세요. 토큰과 .env 파일을 Git에 저장하지 마세요.

## 설치 결과

- 소스: `~/monitoring-source`
- 배포용 독립 checkout: `~/deploy-checkouts/dev` (환경에 따라 변경)
- Runner: `~/actions-runner-dev`
- Runner 라벨: `deploy-dev` / `deploy-stage` / `deploy-prod`
- 앱 서비스: `main-api-dev.service` (기존 정책대로 설치 시 부팅 자동 시작은 비활성)
- Runner 서비스: 공식 `svc.sh install`로 systemd 등록 및 부팅 자동 시작

`systemctl list-units 'actions.runner*'`로 상태를 확인합니다. Runner 계정과 설치 계정은 동일해야 하며, GitHub Environment의 `DEPLOY_ROOT`가 설정돼 있으면 설치 경로와 일치해야 합니다. 설정되지 않으면 workflow는 `~/deploy-checkouts/<환경>`을 사용합니다.

## 검증과 운영 주의

설치 스크립트는 기존 Runner가 없다는 전제로 설계되었습니다. 실제 EC2에서 최초 설치, 재부팅, Push 배포 및 헬스체크를 별도 검증해야 합니다. 기존 WSL의 `deploy-local` Runner는 새 workflow의 환경별 라벨과 일치하지 않아 작업을 처리하지 못합니다. 관리자 승인/예약 배포는 추후 별도 기능으로 구현합니다.
