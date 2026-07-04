#!/bin/bash
# ============================================================
# cnb-sync.sh — 通用 cnb.cool ↔ GitHub 双向同步脚本
#
# 用法:
#   ./cnb-sync.sh sync          # 双向同步
#   ./cnb-sync.sh push          # 单向推送 (cnb→GitHub)
#   ./cnb-sync.sh pull          # 单向拉取 (GitHub→cnb)
#   ./cnb-sync.sh status        # 查看同步状态
#
# 环境变量 (必填):
#   GITHUB_TOKEN  — GitHub PAT (repo 权限)
#   CNB_REPO_SLUG — cnb 仓库路径（如 sc.hwd/sono）
#
# 环境变量 (可选):
#   GITHUB_USER   — GitHub 用户名（默认同 cnb owner）
#   SYNC_BRANCHES — 要同步的分支列表，空格分隔（默认: 所有分支）
#   DRY_RUN       — true=预览不执行
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="${SCRIPT_DIR}/.sync.lock"

GITHUB_TOKEN="${GITHUB_TOKEN:?❌ 请设置 GITHUB_TOKEN}"
CNB_REPO_SLUG="${CNB_REPO_SLUG:?❌ 请设置 CNB_REPO_SLUG}"

GITHUB_USER="${GITHUB_USER:-$(echo "$CNB_REPO_SLUG" | cut -d/ -f1)}"
GITHUB_REPO="https://oauth2:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/$(echo "$CNB_REPO_SLUG" | cut -d/ -f2).git"
GITHUB_REMOTE="github"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { log "❌ ERROR: $*"; exit 1; }
info() { log "ℹ️  INFO: $*"; }
ok() { log "✅ $*"; }

acquire_lock() {
  if [ -f "$LOCK_FILE" ]; then
    local pid
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
      error "同步已在进行中 (PID: $pid)。请先等待完成或手动删除 $LOCK_FILE"
    fi
    rm -f "$LOCK_FILE"
    info "清理过期锁文件"
  fi
  echo $$ > "$LOCK_FILE"
  trap 'rm -f "$LOCK_FILE"' EXIT
}

setup_remote() {
  if git remote get-url "$GITHUB_REMOTE" >/dev/null 2>&1; then
    info "更新已有 remote: $GITHUB_REMOTE"
    git remote set-url "$GITHUB_REMOTE" "$GITHUB_REPO"
  else
    info "添加新 remote: $GITHUB_REMOTE"
    git remote add "$GITHUB_REMOTE" "$GITHUB_REPO"
  fi
}

get_branches() {
  if [ -n "${SYNC_BRANCHES:-}" ]; then
    echo "$SYNC_BRANCHES"
  else
    git branch --format='%(refname:short)'
  fi
}

do_push() {
  log "📤 开始推送: cnb(${CNB_REPO_SLUG}) → GitHub"
  setup_remote
  
  local branches
  branches=$(get_branches)
  
  while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    log "  推送分支: $branch"
    if [ "${DRY_RUN:-false}" = "true" ]; then
      info "  [DRY RUN] git push $GITHUB_REMOTE $branch"
    else
      git push "$GITHUB_REMOTE" "$branch" 2>&1 || info "  ⚠️ 分支 $branch 推送失败"
    fi
  done <<< "$branches"
  
  log "  推送所有标签..."
  if [ "${DRY_RUN:-false}" != "true" ]; then
    git push "$GITHUB_REMOTE" --tags 2>&1 || info "  ⚠️ 标签推送失败"
  fi
  
  ok "推送完成"
}

do_pull() {
  log "📥 开始拉取: GitHub → cnb(${CNB_REPO_SLUG})"
  setup_remote
  
  local branches
  branches=$(get_branches)
  
  while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    log "  拉取分支: $branch"
    if [ "${DRY_RUN:-false}" = "true" ]; then
      info "  [DRY RUN] git pull $GITHUB_REMOTE $branch"
    else
      git pull "$GITHUB_REMOTE" "$branch" 2>&1 || info "  ⚠️ 分支 $branch 拉取失败"
    fi
  done <<< "$branches"
  
  ok "拉取完成"
}

do_sync() {
  log "🔄 开始双向同步"
  do_push
  do_pull
  ok "双向同步完成"
}

do_status() {
  log "📊 同步状态"
  setup_remote
  local current_branch
  current_branch=$(git symbolic-ref --short HEAD)
  
  echo ""
  echo "  当前分支: $current_branch"
  echo "  cnb:      https://cnb.cool/${CNB_REPO_SLUG}"
  echo "  github:   https://github.com/${GITHUB_USER}/$(echo "$CNB_REPO_SLUG" | cut -d/ -f2)"
  echo ""
  
  log "  比较 $current_branch 分支差异..."
  if [ "${DRY_RUN:-false}" != "true" ]; then
    local cnb_sha github_sha
    cnb_sha=$(git rev-parse HEAD)
    github_sha=$(git ls-remote "$GITHUB_REMOTE" "refs/heads/$current_branch" | awk '{print $1}')
    
    if [ "$cnb_sha" = "$github_sha" ]; then
      ok "分支 $current_branch 已同步"
    elif [ -n "$github_sha" ]; then
      info "分支 $current_branch 有差异"
      echo "  cnb SHA:    $cnb_sha"
      echo "  github SHA: $github_sha"
    else
      info "GitHub 上尚无此分支"
    fi
  fi
}

acquire_lock

case "${1:-push}" in
  sync)   do_sync ;;
  push)   do_push ;;
  pull)   do_pull ;;
  status) do_status ;;
  *)
    error "未知命令: $1
用法: $0 {sync|push|pull|status}"
    ;;
esac
