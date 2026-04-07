#!/bin/sh
# git-sync.sh — Pull remote changes and auto-commit/push local changes.
#
# Intended to run as a cron job inside the OpenClaw gateway container.
# Example crontab entry (every 5 minutes):
# */5 * * * * flock -n /tmp/git-sync.lock /home/node/scripts/git-sync.sh /home/node/.openclaw/agents/personal/obsidian >> /var/log/git-sync.log 2>&1
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

echo "[$TIMESTAMP] git-sync: pulling remote changes"
if ! git pull --rebase --autostash 2>&1; then
  echo "[$TIMESTAMP] git-sync: git pull --rebase --autostash failed; repository may need manual attention"
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "[$TIMESTAMP] git-sync: local changes detected, preparing staged set"

  # Only stage intended content
  git add README.md RULES.md knowledge_base

  # Never auto-sync Obsidian app config
  git restore --staged 'knowledge_base/.obsidian/**' 2>/dev/null || true
  git restore --staged '.obsidian/**' 2>/dev/null || true

  if [ -n "$(git diff --cached --name-only)" ]; then
    echo "[$TIMESTAMP] git-sync: creating auto-commit"
    git commit -m "openclaw: auto-sync $TIMESTAMP"

    echo "[$TIMESTAMP] git-sync: pushing commit"
    if ! git push 2>&1; then
      echo "[$TIMESTAMP] git-sync: git push failed; local commit exists but was not pushed"
      exit 1
    fi

    echo "[$TIMESTAMP] git-sync: committed and pushed local changes"
  else
    echo "[$TIMESTAMP] git-sync: changes detected, but nothing matched auto-sync rules"
  fi
else
  echo "[$TIMESTAMP] git-sync: no local changes"
fi

echo "[$TIMESTAMP] git-sync: done"
