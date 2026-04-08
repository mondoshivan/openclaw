#!/bin/sh
# git-sync.sh — Pull remote changes and auto-commit/push local changes.
#
# Intended to run as a cron job inside the OpenClaw gateway container.
# Example crontab entry (every 5 minutes):
# */5 * * * * flock -n /tmp/git-sync.lock /home/node/scripts/git-sync.sh >> /var/log/git-sync.log 2>&1
#
# Usage: git-sync.sh [repo-dir]
# If no repo-dir is given, sync all agent Obsidian checkouts under:
#   /home/node/.openclaw/agents/*/obsidian

set -eu

sync_repo() {
  REPO_DIR="$1"

  if [ ! -d "$REPO_DIR/.git" ]; then
    echo "[$TIMESTAMP] git-sync: skip $REPO_DIR (not a git repository)"
    return 0
  fi

  cd "$REPO_DIR"
  echo "[$TIMESTAMP] git-sync: starting in $REPO_DIR"
  echo "[$TIMESTAMP] git-sync: pulling remote changes"
  if ! git pull --rebase --autostash 2>&1; then
    echo "[$TIMESTAMP] git-sync: git pull --rebase --autostash failed in $REPO_DIR; repository may need manual attention"
    return 1
  fi

  if [ -n "$(git status --porcelain)" ]; then
    echo "[$TIMESTAMP] git-sync: local changes detected in $REPO_DIR, preparing staged set"

    git add README.md RULES.md knowledge_base

    git restore --staged 'knowledge_base/.obsidian/**' 2>/dev/null || true
    git restore --staged '.obsidian/**' 2>/dev/null || true

    if [ -n "$(git diff --cached --name-only)" ]; then
      echo "[$TIMESTAMP] git-sync: creating auto-commit in $REPO_DIR"
      git commit -m "openclaw: auto-sync $TIMESTAMP"

      echo "[$TIMESTAMP] git-sync: pushing commit from $REPO_DIR"
      if ! git push 2>&1; then
        echo "[$TIMESTAMP] git-sync: git push failed in $REPO_DIR; local commit exists but was not pushed"
        return 1
      fi

      echo "[$TIMESTAMP] git-sync: committed and pushed local changes in $REPO_DIR"
    else
      echo "[$TIMESTAMP] git-sync: changes detected in $REPO_DIR, but nothing matched auto-sync rules"
    fi
  else
    echo "[$TIMESTAMP] git-sync: no local changes in $REPO_DIR"
  fi

  echo "[$TIMESTAMP] git-sync: done in $REPO_DIR"
}

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TARGET_DIR="${1:-}"

if [ -n "$TARGET_DIR" ]; then
  if [ ! -d "$TARGET_DIR" ]; then
    echo "Usage: git-sync.sh [repo-dir]" >&2
    exit 1
  fi
  sync_repo "$TARGET_DIR"
  exit 0
fi

FOUND=0
EXIT_CODE=0
for repo in /home/node/.openclaw/agents/*/obsidian; do
  [ -d "$repo" ] || continue
  FOUND=1
  sync_repo "$repo" || EXIT_CODE=1
  cd /home/node/.openclaw/agents/personal
  echo "[$TIMESTAMP] git-sync: --"
done

if [ "$FOUND" -eq 0 ]; then
  echo "[$TIMESTAMP] git-sync: no agent Obsidian repos found"
fi

exit "$EXIT_CODE"
