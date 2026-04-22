#!/bin/sh
# git-sync.sh — Pull remote changes and auto-commit/push local changes.
#
# Intended to run as a cron job inside the OpenClaw gateway container.
# Example crontab entry (every 5 minutes):
# */5 * * * * flock -n /tmp/git-sync.lock /home/node/scripts/git-sync.sh >> /var/log/git-sync.log 2>&1
#
# Usage: git-sync.sh [repo-dir [mode]]
# mode: "obsidian" (default) or "skills"
# If no repo-dir is given, sync all agent checkouts under:
#   /home/node/.openclaw/agents/*/obsidian  (mode=obsidian)
#   /home/node/.openclaw/agents/*/skills    (mode=skills)

set -eu

PULL_TIMEOUT="${GIT_SYNC_PULL_TIMEOUT:-90}"
PUSH_TIMEOUT="${GIT_SYNC_PUSH_TIMEOUT:-90}"
ROOT_DIR="${GIT_SYNC_ROOT_DIR:-/home/node/.openclaw/agents/personal}"

log() {
  printf '[%s] git-sync: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

sync_repo() {
  REPO_DIR="$1"
  MODE="${2:-obsidian}"

  if [ ! -d "$REPO_DIR/.git" ]; then
    log "skip $REPO_DIR (not a git repository)"
    return 0
  fi

  cd "$REPO_DIR"
  log "starting in $REPO_DIR (mode=$MODE)"
  log "pulling remote changes in $REPO_DIR (timeout ${PULL_TIMEOUT}s)"
  if ! timeout "$PULL_TIMEOUT" git pull --rebase --autostash >/tmp/git-sync-pull.log 2>&1; then
    status=$?
    log "git pull failed in $REPO_DIR (exit=$status)"
    sed 's/^/[git-pull] /' /tmp/git-sync-pull.log || true
    log "repository may need manual attention: $REPO_DIR"
    return 1
  fi
  sed 's/^/[git-pull] /' /tmp/git-sync-pull.log || true

  if [ -n "$(git status --porcelain)" ]; then
    log "local changes detected in $REPO_DIR, preparing staged set"

    if [ "$MODE" = "skills" ]; then
      git add -A
    else
      git add README.md RULES.md knowledge_base

      git restore --staged 'knowledge_base/.obsidian/**' 2>/dev/null || true
      git restore --staged '.obsidian/**' 2>/dev/null || true
    fi

    if [ -n "$(git diff --cached --name-only)" ]; then
      log "creating auto-commit in $REPO_DIR"
      git commit -m "openclaw: auto-sync $(date -u +%Y-%m-%dT%H:%M:%SZ)"

      log "pushing commit from $REPO_DIR (timeout ${PUSH_TIMEOUT}s)"
      if ! timeout "$PUSH_TIMEOUT" git push >/tmp/git-sync-push.log 2>&1; then
        status=$?
        log "git push failed in $REPO_DIR (exit=$status)"
        sed 's/^/[git-push] /' /tmp/git-sync-push.log || true
        log "local commit exists but was not pushed: $REPO_DIR"
        return 1
      fi
      sed 's/^/[git-push] /' /tmp/git-sync-push.log || true

      log "committed and pushed local changes in $REPO_DIR"
    else
      log "changes detected in $REPO_DIR, but nothing matched auto-sync rules"
    fi
  else
    log "no local changes in $REPO_DIR"
  fi

  log "done in $REPO_DIR"
}

TARGET_DIR="${1:-}"
TARGET_MODE="${2:-obsidian}"

if [ -n "$TARGET_DIR" ]; then
  if [ ! -d "$TARGET_DIR" ]; then
    echo "Usage: git-sync.sh [repo-dir [mode]]" >&2
    exit 1
  fi
  sync_repo "$TARGET_DIR" "$TARGET_MODE"
  exit 0
fi

FOUND=0
EXIT_CODE=0

for repo in /home/node/.openclaw/agents/*/obsidian; do
  [ -d "$repo" ] || continue
  FOUND=1
  sync_repo "$repo" "obsidian" || EXIT_CODE=1
  cd "$ROOT_DIR"
  log "--"
done

for repo in /home/node/.openclaw/agents/*/skills; do
  [ -d "$repo" ] || continue
  FOUND=1
  sync_repo "$repo" "skills" || EXIT_CODE=1
  cd "$ROOT_DIR"
  log "--"
done

if [ "$FOUND" -eq 0 ]; then
  log "no agent repos found (obsidian or skills)"
fi

exit "$EXIT_CODE"
