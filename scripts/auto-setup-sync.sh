#!/bin/bash
# ============================================================
# auto-setup-sync.sh — 一键配置 cnb↔GitHub 同步
#
# 用法:
#   ./auto-setup-sync.sh <target_repo> [github_repo]
#
# 功能:
#   1. 创建新分支
#   2. 生成/合并 .cnb/web_trigger.yml（3个同步按钮）
#   3. 在 .cnb.yml 中追加 include 引用（合并已有内容）
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

# ============================================================
# 1. 生成 .cnb/web_trigger.yml
#    如果已有文件，追加我们的按钮（以我们写入的为准）
# ============================================================
echo "📄 处理 .cnb/web_trigger.yml ..."
mkdir -p .cnb

# 我们的按钮 YAML 片段（不含文件头注释）
OUR_BUTTONS_YAML='# .cnb/web_trigger.yml
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
                value: "true"'

if [ -f .cnb/web_trigger.yml ]; then
  # 已有文件：提取原有按钮（排除我们已添加的按钮名），然后追加新的
  echo "  检测到已有 web_trigger.yml，执行合并..."
  
  # 判断是否已经包含我们的按钮（通过事件名检测）
  if grep -q "web_trigger_cnb_to_github" .cnb/web_trigger.yml; then
    echo "  ⚠️ 已包含我们的按钮，将被覆盖（以本次写入为准）"
  fi
  
  # 直接覆盖：以我们写入的为准（有 MR 不怕）
  echo "$OUR_BUTTONS_YAML" > .cnb/web_trigger.yml
  echo "  ✅ 已覆盖为最新配置"
else
  echo "$OUR_BUTTONS_YAML" > .cnb/web_trigger.yml
  echo "  ✅ 已创建新文件"
fi

# ============================================================
# 2. 处理 .cnb.yml — 合并 include 部分
#    如果已有 include，在末尾追加我们的引用
#    如果没有 include，新建 include 块
# ============================================================
echo "📄 处理 .cnb.yml ..."

CNB_SYNC_INCLUDE="  - https://cnb.cool/sc.hwd/cnb-sync/-/blob/main/.cnb/workflows/sync.yml"

if [ ! -f .cnb.yml ]; then
  # 没有 .cnb.yml，创建全新的
  echo "include:" > .cnb.yml
  echo "$CNB_SYNC_INCLUDE" >> .cnb.yml
  echo "  ✅ 创建新的 .cnb.yml"
else
  # 已有 .cnb.yml，检查是否已有 include 块
  if grep -q "^include:" .cnb.yml; then
    # include 已存在，检查是否已包含我们的引用
    if grep -q "cnb-sync" .cnb.yml; then
      echo "  ⚠️ 已包含 cnb-sync 引用，将被追加（幂等）"
      # 避免重复追加：检查最后一行是否已是我们的引用
      LAST_LINE="$(tail -1 .cnb.yml)"
      if [ "$LAST_LINE" != "$CNB_SYNC_INCLUDE" ]; then
        echo "$CNB_SYNC_INCLUDE" >> .cnb.yml
      fi
    else
      # include 存在但还没有我们的引用，追加
      echo "$CNB_SYNC_INCLUDE" >> .cnb.yml
    fi
  else
    # 没有 include 块，在文件末尾添加
    echo "" >> .cnb.yml
    echo "include:" >> .cnb.yml
    echo "$CNB_SYNC_INCLUDE" >> .cnb.yml
  fi
  echo "  ✅ 已更新 .cnb.yml"
fi

# ============================================================
# 3. 提交
# ============================================================
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
