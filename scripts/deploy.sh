#!/bin/bash
# FactCheckr 배포 스크립트 — 서버에서 git pull 후 Docker Compose 재빌드
set -e

SERVER="root@158.247.227.111"
APP_DIR="/opt/factcheckr"
REPO="https://github.com/git-surfer-k/factcheckr-01.git"

echo "=== FactCheckr 배포 시작 ==="

# 1. 서버에 앱 디렉토리 생성 + 코드 배포
echo "[1/4] 코드 배포..."
ssh $SERVER "
  if [ ! -d $APP_DIR ]; then
    git clone $REPO $APP_DIR
  else
    cd $APP_DIR && git pull origin main
  fi
"

# 2. 환경변수 파일 확인
echo "[2/4] 환경변수 확인..."
ssh $SERVER "
  if [ ! -f $APP_DIR/.env ]; then
    echo '환경변수 파일 생성 중...'
    cat > $APP_DIR/.env << 'ENVEOF'
SECRET_KEY_BASE=$(openssl rand -hex 64)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
OPENAI_API_KEY=
BIGKINDS_API_KEY=
ENVEOF
    echo '.env 파일이 생성되었습니다. API 키를 설정하세요.'
  else
    echo '.env 파일 존재 확인'
  fi
"

# 3. Docker Compose 빌드 + 시작
echo "[3/4] Docker 빌드 및 시작..."
ssh $SERVER "
  cd $APP_DIR && \
  docker compose -f docker-compose.prod.yml build --no-cache && \
  docker compose -f docker-compose.prod.yml up -d
"

# 4. 상태 확인
echo "[4/4] 배포 상태 확인..."
sleep 5
ssh $SERVER "cd $APP_DIR && docker compose -f docker-compose.prod.yml ps"

echo ""
echo "=== 배포 완료 ==="
echo "  웹: http://158.247.227.111"
echo "  AI: http://158.247.227.111:8000"
