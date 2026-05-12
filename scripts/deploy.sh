#!/bin/bash
# Deploy hecate-daemon to ghcr.io
# Usage: ./scripts/deploy.sh [tag]
# Default tag: main

set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:-main}"
IMAGE="codeberg.org/hecate-social/hecate-daemon:${TAG}"

echo "==> Building ${IMAGE}..."
docker build -t "${IMAGE}" .

echo "==> Pushing ${IMAGE}..."
docker push "${IMAGE}"

echo "==> Done! Image pushed: ${IMAGE}"
echo ""
echo "To deploy to cluster, run:"
echo "  kubectl rollout restart daemonset/hecate-daemon -n hecate"
