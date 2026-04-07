#!/bin/sh
# git-sync.sh — Pull remote changes and auto-commit/push local changes.
#
# Intended to run as a cron job inside the OpenClaw gateway container.
# Example crontab entry (every 5 minutes):
#   */5 * * * * /home/node/scripts/git-sync.sh /home/node/obsidian >> /tmp/git-sync.log 2>&1
#
# Usage: git-sync.sh <repo-dir>

set -eu

REPO_DIR="${1:-}"

if [ -z "$REPO_DIR" ]; then
  echo "Usage: git-sync.sh <repo-dir>" >&2
  exit 1
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Error: $REPO_DIR is not a git repository" >&2
  exit 1
fi

cd "$REPO_DIR"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[$TIMESTAMP] git-sync: starting in $REPO_DIR"

# Pull remote changes, rebase local commits on top, stash uncommitted work temporarily
if ! git pull --rebase --autostash 2>&1; then
  echo "[$TIMESTAMP] git-sync: pull failed, skipping push"
  exit 1
fi

# If there are local changes, commit and push them
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "openclaw: auto-sync $TIMESTAMP"
  if ! git push 2>&1; then
    echo "[$TIMESTAMP] git-sync: push failed"
    exit 1
  fi
  echo "[$TIMESTAMP] git-sync: committed and pushed local changes"
else
  echo "[$TIMESTAMP] git-sync: no local changes"
fi
