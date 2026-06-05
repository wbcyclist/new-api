#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-jasio/new-api}"
BUILDER="${BUILDER:-new-api-multiarch}"
PUSH_LATEST="${PUSH_LATEST:-1}"
PLATFORMS="${PLATFORMS:-linux/amd64 linux/arm64}"
COSIGN="${COSIGN:-0}"

usage() {
  cat <<'EOF'
Build and publish new-api Docker images using the same shape as upstream:
  1. build/push TAG-amd64 and TAG-arm64
  2. build/push latest-amd64 and latest-arm64
  3. create multi-arch manifests TAG and latest

Usage:
  scripts/docker-release.sh <tag>

Examples:
  scripts/docker-release.sh v0.10.8-alpha.3
  IMAGE=jasio/new-api PUSH_LATEST=0 scripts/docker-release.sh v0.10.8-alpha.3

Environment:
  IMAGE        Docker Hub image name. Default: jasio/new-api
  BUILDER      buildx builder name. Default: new-api-multiarch
  PUSH_LATEST  Push latest/latest-arch tags when 1. Default: 1
  PLATFORMS    Space-separated platforms. Default: "linux/amd64 linux/arm64"
  COSIGN       Sign pushed tags with cosign when 1. Default: 0
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

ensure_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

ensure_builder() {
  if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
    docker buildx create --name "$BUILDER" --driver docker-container --use >/dev/null
  else
    docker buildx use "$BUILDER"
  fi

  docker buildx inspect --bootstrap >/dev/null
}

sign_image() {
  if [ "$COSIGN" != "1" ]; then
    return
  fi

  ensure_command cosign
  cosign sign --yes "$1"
}

arch_from_platform() {
  case "$1" in
    linux/amd64) echo "amd64" ;;
    linux/arm64) echo "arm64" ;;
    *) die "unsupported platform: $1" ;;
  esac
}

TAG="${1:-}"
if [ -z "$TAG" ] || [ "$TAG" = "-h" ] || [ "$TAG" = "--help" ]; then
  usage
  exit 0
fi

ensure_command docker
ensure_command git

ROOT="$(repo_root)"
cd "$ROOT"

[ -f Dockerfile ] || die "Dockerfile not found in $ROOT"

if ! docker info >/dev/null 2>&1; then
  die "Docker is not running or not reachable"
fi

if ! docker buildx version >/dev/null 2>&1; then
  die "Docker buildx is not available"
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  COMMIT="$(git rev-parse HEAD)"
  SHORT_COMMIT="$(git rev-parse --short HEAD)"
  echo "Repository: $ROOT"
  echo "Branch:     $(git branch --show-current 2>/dev/null || true)"
  echo "Commit:     $SHORT_COMMIT"
  if [ -n "$(git status --porcelain)" ]; then
    echo "Working tree has local changes; they will be included in the Docker build context."
  fi
else
  COMMIT=""
fi

echo "$TAG" > VERSION
echo "Wrote VERSION=$TAG"

ensure_builder

echo "Image:      $IMAGE"
echo "Builder:    $BUILDER"
echo "Platforms:  $PLATFORMS"
echo "Cosign:     $COSIGN"

labels=(
  --label "org.opencontainers.image.title=new-api"
  --label "org.opencontainers.image.version=$TAG"
  --label "org.opencontainers.image.source=https://github.com/QuantumNous/new-api"
)

if [ -n "$COMMIT" ]; then
  labels+=(--label "org.opencontainers.image.revision=$COMMIT")
fi

for platform in $PLATFORMS; do
  arch="$(arch_from_platform "$platform")"
  tags=(-t "$IMAGE:$TAG-$arch")

  if [ "$PUSH_LATEST" = "1" ]; then
    tags+=(-t "$IMAGE:latest-$arch")
  fi

  echo
  echo "Building and pushing $platform as $IMAGE:$TAG-$arch"
  docker buildx build \
    --builder "$BUILDER" \
    --platform "$platform" \
    --push \
    --provenance mode=max \
    --sbom true \
    "${labels[@]}" \
    "${tags[@]}" \
    .

  sign_image "$IMAGE:$TAG-$arch"
  if [ "$PUSH_LATEST" = "1" ]; then
    sign_image "$IMAGE:latest-$arch"
  fi
done

manifest_sources=()
latest_sources=()
for platform in $PLATFORMS; do
  arch="$(arch_from_platform "$platform")"
  manifest_sources+=("$IMAGE:$TAG-$arch")
  latest_sources+=("$IMAGE:latest-$arch")
done

echo
echo "Creating multi-arch manifest $IMAGE:$TAG"
docker buildx imagetools create \
  -t "$IMAGE:$TAG" \
  "${manifest_sources[@]}"
sign_image "$IMAGE:$TAG"

if [ "$PUSH_LATEST" = "1" ]; then
  echo
  echo "Creating multi-arch manifest $IMAGE:latest"
  docker buildx imagetools create \
    -t "$IMAGE:latest" \
    "${latest_sources[@]}"
  sign_image "$IMAGE:latest"
fi

echo
echo "Published:"
docker buildx imagetools inspect "$IMAGE:$TAG"

if [ "$PUSH_LATEST" = "1" ]; then
  echo
  echo "Latest manifest:"
  docker buildx imagetools inspect "$IMAGE:latest"
fi
