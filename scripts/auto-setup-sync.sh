#!/bin/bash
# ============================================================
# auto-setup-sync.sh — 一键配置 cnb↔GitHub 同步
#
# 用法:
#   ./auto-setup-sync.sh <target_repo> [github_repo]
#
# 功能:
#   1. 创建新分支
#   2. 生成 .cnb/web_trigger.yml（3个同步按钮）
#   3. 在 .cnb.yml 中追加 include 引用
#   4. 提交并推送，创建 MR
# ============================================================

set -euo pipefail

TARGET_REPO="${1:?用法: $0 <target_repo> [github_repo]}"
GITHUB_REPO="${2:-}"

export GITHUB_TOKEN="${GITHUB_TOKEN:?❌ 请设置 GITHUB_TOKEN}"
export CNB_TOKEN="${CNB_TOKEN:?❌ 请设置 CNB_TOKEN}"
export CNB_REPO_SLUG="${CNB_REPO_SLUG:?❌ 请设置 CNB_REPO_SLUG}"

cd /workspace

# 获取组织名和仓库名
ORG="$(echo "$CNB_REPO_SLUG" | cut -d/ -f1)"
MY_REPO="$(echo "$CNB_REPO_SLUG" | cut -d/ -f2)"

# 生成唯一分支名
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SETUP_BRANCH="auto-setup-sync-${TARGET_REPO}-${TIMESTAMP}"

echo "📝 创建分支: $SETUP_BRANCH"
git checkout -b "$SETUP_BRANCH"

# 1. 生成 .cnb/web_trigger.yml
echo "📄 生成 .cnb/web_trigger.yml ..."
mkdir -p .cnb

cat > .cnb/web_trigger.yml << 'WTEOF'
# .cnb/web_trigger.yml
# 自动生成的同步按钮配置
# 来源: ⚙️ 一键配置同步

branch:
  - buttons:
      - name: 🚀 同步到GitHub
        description: 将当前分支推送到 GitHub 仓库
        event: web_trigger_cnb_to_github
        inputs:
          mode:
            type: select
            required: true
            default: "current"
            name: 同步范围
            options:
              - name: 当前分支
                value: "current"
              - name: 全部分支
                value: "all"
          branch:
            type: input
            required: false
            name: 分支名
          force:
            type: switch
            required: false
            default: "false"
            name: 强制覆盖
          github_repo:
            type: input
            required: false
            name: GitHub 仓库
            description: 目标 GitHub 仓库地址（如 owner/repo，留空则使用默认）
      
      - name: 📥 从GitHub拉取
        description: 从 GitHub 仓库拉取最新代码
        event: web_trigger_github_to_cnb
        inputs:
          mode:
            type: select
            required: true
            default: "current"
            name: 同步范围
            options:
              - name: 当前分支
                value: "current"
              - name: 全部分支
                value: "all"
          branch:
            type: input
            required: false
            name: 分支名
          github_repo:
            type: input
            required: false
            name: GitHub 仓库
            description: 源 GitHub 仓库地址
      
      - name: 🔄 双向同步
        description: 先推送再拉取，保持两边一致
        event: web_trigger_full_sync
        inputs:
          mode:
            type: select
            required: true
            default: "current"
            name: 同步范围
            options:
              - name: 当前分支
                value: "current"
              - name: 全部分支
                value: "all"
          branch:
            type: input
            required: false
            name: 分支名
          force:
            type: switch
            required: false
            default: "false"
            name: 强制覆盖
          github_repo:
            type: input
            required: false
            name: GitHub 仓库
          dry_run:
            type: select
            required: false
            default: "false"
            name: 预览模式
            options:
              - name: 直接执行
                value: "false"
              - name: 预览模式
                value: "true"
WTEOF

# 2. 生成 .cnb.yml 的 include 部分
echo "📄 更新 .cnb.yml ..."

if [ ! -f .cnb.yml ]; then
  cat > .cnb.yml << 'YMLEOF'
include:
  - https://cnb.cool/sc.hwd/cnb-sync/-/blob/main/.cnb/workflows/sync.yml
YMLEOF
else
  if ! grep -q "^include:" .cnb.yml; then
    echo "" >> .cnb.yml
    echo "include:" >> .cnb.yml
    echo "  - https://cnb.cool/sc.hwd/cnb-sync/-/blob/main/.cnb/workflows/sync.yml" >> .cnb.yml
  else
    echo "  - https://cnb.cool/sc.hwd/cnb-sync/-/blob/main/.cnb/workflows/sync.yml" >> .cnb.yml
  fi
fi

# 3. 提交
COMMIT_MSG="feat: 一键配置 cnb↔GitHub 同步 (${TARGET_REPO})

- 添加 .cnb/web_trigger.yml（3个同步按钮）
- 添加 include 引用 cnb-sync 流水线
- 目标 GitHub 仓库: ${GITHUB_REPO:-默认}"

git add .cnb/web_trigger.yml .cnb.yml
git commit -m "$COMMIT_MSG"

# 4. 推送
echo "📤 推送分支 ..."
git push origin "$SETUP_BRANCH"

# 5. 创建 MR
echo "🔗 创建 MR ..."
MR_URL="https://api.cnb.cool/${ORG}/${MY_REPO}/-/merge-requests"

MR_RESPONSE=$(curl -s -X POST \
  -H "Authorization: $CNB_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.cnb.api+json" \
  -d "{
    \"source_branch\": \"${SETUP_BRANCH}\",
    \"target_branch\": \"main\",
    \"title\": \"feat: 一键配置同步 (${TARGET_REPO})\",
    \"description\": \"一键配置 cnb↔GitHub 同步（${TARGET_REPO}）\\n\\n- 添加 .cnb/web_trigger.yml（3个同步按钮）\\n- 添加 include 引用 cnb-sync 流水线\\n- 目标 GitHub 仓库: ${GITHUB_REPO:-默认}\"
  }" 2>&1)

echo "$MR_RESPONSE"

if echo "$MR_RESPONSE" | grep -q '"iid"'; then
  MR_IID=$(echo "$MR_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['iid'])" 2>/dev/null || echo "?")
  echo ""
  echo "✅ MR 创建成功!"
  echo "   https://cnb.cool/${ORG}/${MY_REPO}/-/merge-requests/${MR_IID}"
else
  echo "❌ MR 创建失败: $MR_RESPONSE"
  exit 1
fi
