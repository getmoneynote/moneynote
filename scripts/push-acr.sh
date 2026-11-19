#!/usr/bin/env bash
# 本地构建并推送镜像到阿里云 ACR，等价于 .github/workflows/acr-image.yml
#
# 用法（在仓库根目录或任意目录执行均可）：
#   ACR_USERNAME=xxx ACR_PASSWORD=xxx ./scripts/push-acr.sh
#   ./scripts/push-acr.sh --platform linux/amd64          # 只构建本机架构，快很多
#   ./scripts/push-acr.sh --no-latest                     # 只推 sha tag，不动 latest
#   ./scripts/push-acr.sh --dry-run                       # 构建但不推送（仅单架构）
#
# 环境变量：
#   ACR_USERNAME   阿里云账号全名或子账号（必填，--dry-run 除外）
#   ACR_PASSWORD   ACR 控制台设置的固定密码（必填，--dry-run 除外）
#   ACR_REGISTRY   默认 registry.cn-hangzhou.aliyuncs.com
#   ACR_REPOSITORY 默认 moneynote/moneynote-api
set -euo pipefail

ACR_REGISTRY="${ACR_REGISTRY:-registry.cn-hangzhou.aliyuncs.com}"
ACR_REPOSITORY="${ACR_REPOSITORY:-moneynote/moneynote-api}"
BUILDER="${BUILDER:-acr-builder}"

PLATFORMS="linux/amd64,linux/arm64"
PUSH=1
LATEST=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORMS="$2"; shift 2 ;;
    --no-latest) LATEST=0; shift ;;
    --dry-run) PUSH=0; shift ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "未知参数: $1" >&2
      exit 1 ;;
  esac
done

cd "$(dirname "$0")/.."

# 本地构建常见于未提交状态，带 -dirty 后缀免得和 CI 推的同名 sha 混淆
SHA="$(git rev-parse --short HEAD)"
if ! git diff --quiet || ! git diff --cached --quiet; then
  SHA="${SHA}-dirty"
fi

IMAGE="${ACR_REGISTRY}/${ACR_REPOSITORY}"

# --load 不支持多平台，dry-run 时强制收敛到单架构
if [[ "$PUSH" == 0 ]]; then
  case "$PLATFORMS" in
    *,*) PLATFORMS="${PLATFORMS%%,*}" ;;
  esac
fi

TAGS=(--tag "${IMAGE}:${SHA}")
if [[ "$LATEST" == 1 && "$PUSH" == 1 ]]; then
  TAGS+=(--tag "${IMAGE}:latest")
fi

if [[ "$PUSH" == 1 ]]; then
  : "${ACR_USERNAME:?请设置 ACR_USERNAME（阿里云账号全名或子账号）}"
  : "${ACR_PASSWORD:?请设置 ACR_PASSWORD（ACR 控制台里设置的固定密码）}"
  echo "==> 登录 ${ACR_REGISTRY}"
  printf '%s' "$ACR_PASSWORD" | docker login "$ACR_REGISTRY" --username "$ACR_USERNAME" --password-stdin
fi

# 多平台输出到 registry 需要 docker-container driver，默认 docker driver 会直接报错
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
  echo "==> 创建 buildx builder: ${BUILDER}"
  docker buildx create --name "$BUILDER" --driver docker-container --bootstrap
fi

echo "==> 构建 ${IMAGE}  platform=${PLATFORMS}  tag=${SHA}"
docker buildx build \
  --builder "$BUILDER" \
  --platform "$PLATFORMS" \
  "${TAGS[@]}" \
  $([[ "$PUSH" == 1 ]] && echo --push || echo --load) \
  .

if [[ "$PUSH" == 1 ]]; then
  echo "==> 完成，远端平台列表："
  docker buildx imagetools inspect "${IMAGE}:${SHA}"
fi
