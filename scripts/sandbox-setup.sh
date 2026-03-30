#!/usr/bin/env bash
set -euo pipefail

TARGET_IMAGE="${TARGET_IMAGE:-openclaw-sandbox:bookworm-slim}"
OPENCLAW_DOCKER_BUILD_USE_BUILDX="${OPENCLAW_DOCKER_BUILD_USE_BUILDX:-0}"
OPENCLAW_DOCKER_BUILD_PLATFORM="${OPENCLAW_DOCKER_BUILD_PLATFORM:-}"
OPENCLAW_DOCKER_BUILD_PUSH="${OPENCLAW_DOCKER_BUILD_PUSH:-0}"
OPENCLAW_DOCKER_BUILD_CACHE_FROM="${OPENCLAW_DOCKER_BUILD_CACHE_FROM:-}"
OPENCLAW_DOCKER_BUILD_CACHE_TO="${OPENCLAW_DOCKER_BUILD_CACHE_TO:-}"

echo "Building ${TARGET_IMAGE}..."

build_cmd=(docker build)
if [ "${OPENCLAW_DOCKER_BUILD_USE_BUILDX}" = "1" ]; then
  build_cmd=(docker buildx build)
  if [ "${OPENCLAW_DOCKER_BUILD_PUSH}" = "1" ]; then
    build_cmd+=(--push)
  else
    build_cmd+=(--load)
  fi
  if [ -n "${OPENCLAW_DOCKER_BUILD_PLATFORM}" ]; then
    build_cmd+=(--platform "${OPENCLAW_DOCKER_BUILD_PLATFORM}")
  fi
  if [ -n "${OPENCLAW_DOCKER_BUILD_CACHE_FROM}" ]; then
    build_cmd+=(--cache-from "${OPENCLAW_DOCKER_BUILD_CACHE_FROM}")
  fi
  if [ -n "${OPENCLAW_DOCKER_BUILD_CACHE_TO}" ]; then
    build_cmd+=(--cache-to "${OPENCLAW_DOCKER_BUILD_CACHE_TO}")
  fi
fi

"${build_cmd[@]}" \
  -t "${TARGET_IMAGE}" \
  -f Dockerfile.sandbox \
  .

echo "Built ${TARGET_IMAGE}"
