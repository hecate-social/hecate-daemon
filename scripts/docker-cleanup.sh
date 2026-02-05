#!/usr/bin/env bash
set -euo pipefail

# Docker Environment Cleanup Script
# Stops all containers, removes images, volumes, and networks.
# Run this before a fresh hecate install.

echo "=== Docker Environment Cleanup ==="
echo ""
echo "This will:"
echo "  1. Stop ALL running containers"
echo "  2. Remove ALL containers"
echo "  3. Remove ALL images"
echo "  4. Remove ALL volumes"
echo "  5. Remove unused networks"
echo "  6. Clear build cache"
echo ""
echo "WARNING: This is destructive and cannot be undone!"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "--- Stopping all running containers ---"
RUNNING=$(docker ps -q 2>/dev/null || true)
if [ -n "$RUNNING" ]; then
    docker stop $RUNNING
    echo "Stopped $(echo "$RUNNING" | wc -l) containers."
else
    echo "No running containers."
fi

echo ""
echo "--- Removing all containers ---"
ALL=$(docker ps -aq 2>/dev/null || true)
if [ -n "$ALL" ]; then
    docker rm -f $ALL
    echo "Removed $(echo "$ALL" | wc -l) containers."
else
    echo "No containers to remove."
fi

echo ""
echo "--- Removing all images ---"
IMAGES=$(docker images -q 2>/dev/null || true)
if [ -n "$IMAGES" ]; then
    docker rmi -f $IMAGES 2>/dev/null || true
    echo "Removed images."
else
    echo "No images to remove."
fi

echo ""
echo "--- Removing all volumes ---"
VOLUMES=$(docker volume ls -q 2>/dev/null || true)
if [ -n "$VOLUMES" ]; then
    docker volume rm -f $VOLUMES 2>/dev/null || true
    echo "Removed volumes."
else
    echo "No volumes to remove."
fi

echo ""
echo "--- Pruning networks ---"
docker network prune -f 2>/dev/null || true

echo ""
echo "--- Clearing build cache ---"
docker builder prune -af 2>/dev/null || true

echo ""
echo "--- Disk usage after cleanup ---"
docker system df

echo ""
echo "=== Cleanup complete ==="
echo "You can now do a fresh install."
