#!/bin/bash
# ============================================================
# auto-setup-sync.sh — 一键配置 cnb↔GitHub 同步
#
# 用法:
#   ./auto-setup-sync.sh <target_repo> [github_repo]
#
# 功能:
#   1. clone 目标仓库
#   2. 在目标仓库创建分支
#   3. 智能合并 .cnb/web_trigger.yml（追加按钮，保留已有）
#   4. 智能合并 .cnb.yml（追加 include 引用）
#   5. 提交并推送目标仓库
#   6. 在目标仓库创建 MR
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

# 目标仓库完整 slug
TARGET_SLUG="${ORG}/${TARGET_REPO}"

# 生成唯一分支名
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SETUP_BRANCH="auto-setup-sync-${TIMESTAMP}"

# 目标仓库本地路径
TARGET_DIR="/tmp/cnb-sync-target-${TARGET_REPO}-${TIMESTAMP}"

echo "📝 准备目标仓库: ${TARGET_SLUG}"
echo "   分支: ${SETUP_BRANCH}"

# 1. Clone 目标仓库
echo "📥 Clone 目标仓库 ..."
rm -rf "$TARGET_DIR"
git clone "https://cnb:${CNB_TOKEN}@cnb.cool/${TARGET_SLUG}.git" "$TARGET_DIR"
cd "$TARGET_DIR"

# 2. 创建新分支
echo "📝 创建分支: $SETUP_BRANCH"
git checkout -b "$SETUP_BRANCH"

# ============================================================
# 3. 智能合并 .cnb/web_trigger.yml
# ============================================================
echo "📄 处理 .cnb/web_trigger.yml ..."
mkdir -p .cnb

# 检测是否已经包含我们的按钮
HAS_OUR_BUTTONS=false
if [ -f .cnb/web_trigger.yml ]; then
  if grep -q "web_trigger_cnb_to_github" .cnb/web_trigger.yml 2>/dev/null; then
    HAS_OUR_BUTTONS=true
    echo "  ⚠️ 已包含我们的同步按钮，跳过追加"
  fi
fi

if [ "$HAS_OUR_BUTTONS" = false ]; then
  if [ -f .cnb/web_trigger.yml ]; then
    # 已有文件：用 python3 做真正的 YAML 合并
    echo "  检测到已有按钮，将追加我们的同步按钮..."
    
    python3 << 'PYEOF'
import yaml, sys

with open(".cnb/web_trigger.yml", "r") as f:
    doc = yaml.safe_load(f)

our_buttons = [
    {
        "name": "🚀 同步到GitHub",
        "description": "将当前分支推送到 GitHub 仓库",
        "event": "web_trigger_cnb_to_github",
        "inputs": {
            "mode": {
                "type": "select", "required": True, "default": "current",
                "name": "同步范围",
                "options": [
                    {"name": "当前分支", "value": "current"},
                    {"name": "全部分支", "value": "all"}
                ]
            },
            "branch": {
                "type": "input", "required": False, "name": "分支名"
            },
            "force": {
                "type": "switch", "required": False, "default": "false",
                "name": "强制覆盖"
            },
            "github_repo": {
                "type": "input", "required": False, "name": "GitHub 仓库",
                "description": "目标 GitHub 仓库地址（如 owner/repo，留空则使用默认）"
            }
        }
    },
    {
        "name": "📥 从GitHub拉取",
        "description": "从 GitHub 仓库拉取最新代码",
        "event": "web_trigger_github_to_cnb",
        "inputs": {
            "mode": {
                "type": "select", "required": True, "default": "current",
                "name": "同步范围",
                "options": [
                    {"name": "当前分支", "value": "current"},
                    {"name": "全部分支", "value": "all"}
                ]
            },
            "branch": {
                "type": "input", "required": False, "name": "分支名"
            },
            "github_repo": {
                "type": "input", "required": False, "name": "GitHub 仓库",
                "description": "源 GitHub 仓库地址"
            }
        }
    },
    {
        "name": "🔄 双向同步",
        "description": "先推送再拉取，保持两边一致",
        "event": "web_trigger_full_sync",
        "inputs": {
            "mode": {
                "type": "select", "required": True, "default": "current",
                "name": "同步范围",
                "options": [
                    {"name": "当前分支", "value": "current"},
                    {"name": "全部分支", "value": "all"}
                ]
            },
            "branch": {
                "type": "input", "required": False, "name": "分支名"
            },
            "force": {
                "type": "switch", "required": False, "default": "false",
                "name": "强制覆盖"
            },
            "github_repo": {
                "type": "input", "required": False, "name": "GitHub 仓库"
            },
            "dry_run": {
                "type": "select", "required": False, "default": "false",
                "name": "预览模式",
                "options": [
                    {"name": "直接执行", "value": "false"},
                    {"name": "预览模式", "value": "true"}
                ]
            }
        }
    }
]

for branch_cfg in doc.get("branch", []):
    buttons = branch_cfg.get("buttons", [])
    existing_names = {b.get("event") for b in buttons if isinstance(b, dict)}
    for btn in our_buttons:
        evt = btn.get("event")
        if evt and evt not in existing_names:
            buttons.append(btn)
            existing_names.add(evt)

with open(".cnb/web_trigger.yml", "w") as f:
    yaml.dump(doc, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

print("  ✅ 已追加 3 个同步按钮到现有文件")
PYEOF
  else
    # 没有文件，创建全新文件
    echo "  创建新的 web_trigger.yml ..."
    
    python << 'PYEOF'
import yaml

doc = {
    "branch": [{
        "buttons": [
            {
                "name": "🚀 同步到GitHub",
                "description": "将当前分支推送到 GitHub 仓库",
                "event": "web_trigger_cnb_to_github",
                "inputs": {
                    "mode": {
                        "type": "select", "required": True, "default": "current",
                        "name": "同步范围",
                        "options": [
                            {"name": "当前分支", "value": "current"},
                            {"name": "全部分支", "value": "all"}
                        ]
                    },
                    "branch": {
                        "type": "input", "required": False, "name": "分支名"
                    },
                    "force": {
                        "type": "switch", "required": False, "default": "false",
                        "name": "强制覆盖"
                    },
                    "github_repo": {
                        "type": "input", "required": False, "name": "GitHub 仓库",
                        "description": "目标 GitHub 仓库地址（如 owner/repo，留空则使用默认）"
                    }
                }
            },
            {
                "name": "📥 从GitHub拉取",
                "description": "从 GitHub 仓库拉取最新代码",
                "event": "web_trigger_github_to_cnb",
                "inputs": {
                    "mode": {
                        "type": "select", "required": True, "default": "current",
                        "name": "同步范围",
                        "options": [
                            {"name": "当前分支", "value": "current"},
                            {"name": "全部分支", "value": "all"}
                        ]
                    },
                    "branch": {
                        "type": "input", "required": False, "name": "分支名"
                    },
                    "github_repo": {
                        "type": "input", "required": False, "name": "GitHub 仓库",
                        "description": "源 GitHub 仓库地址"
                    }
                }
            },
            {
                "name": "🔄 双向同步",
                "description": "先推送再拉取，保持两边一致",
                "event": "web_trigger_full_sync",
                "inputs": {
                    "mode": {
                        "type": "select", "required": True, "default": "current",
                        "name": "同步范围",
                        "options": [
                            {"name": "当前分支", "value": "current"},
                            {"name": "全部分支", "value": "all"}
                        ]
                    },
                    "branch": {
                        "type": "input", "required": False, "name": "分支名"
                    },
                    "force": {
                        "type": "switch", "required": False, "default": "false",
                        "name": "强制覆盖"
                    },
                    "github_repo": {
                        "type": "input", "required": False, "name": "GitHub 仓库"
                    },
                    "dry_run": {
                        "type": "select", "required": False, "default": "false",
                        "name": "预览模式",
                        "options": [
                            {"name": "直接执行", "value": "false"},
                            {"name": "预览模式", "value": "true"}
                        ]
                    }
                }
            }
        ]
    }]
}

with open(".cnb/web_trigger.yml", "w") as f:
    yaml.dump(doc, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

print("  ✅ 已创建新的 web_trigger.yml")
PYEOF
  fi
else
  echo "  ℹ️ 已包含我们的按钮，无需操作"
fi

# ============================================================
# 4. 处理 .cnb.yml — 合并 include 部分
# ============================================================
echo "📄 处理 .cnb.yml ..."

CNB_SYNC_INCLUDE="  - https://cnb.cool/sc.hwd/cnb-sync/-/blob/main/.cnb/workflows/sync.yml"

if [ ! -f .cnb.yml ]; then
  echo "include:" > .cnb.yml
  echo "$CNB_SYNC_INCLUDE" >> .cnb.yml
  echo "  ✅ 创建新的 .cnb.yml"
else
  if grep -q "^include:" .cnb.yml; then
    if grep -q "cnb-sync" .cnb.yml; then
      LAST_LINE="$(tail -1 .cnb.yml)"
      if [ "$LAST_LINE" != "$CNB_SYNC_INCLUDE" ]; then
        echo "$CNB_SYNC_INCLUDE" >> .cnb.yml
      fi
    else
      echo "$CNB_SYNC_INCLUDE" >> .cnb.yml
    fi
  else
    echo "" >> .cnb.yml
    echo "include:" >> .cnb.yml
    echo "$CNB_SYNC_INCLUDE" >> .cnb.yml
  fi
  echo "  ✅ 已更新 .cnb.yml"
fi

# ============================================================
# 5. 提交并推送到目标仓库
# ============================================================
COMMIT_MSG="feat: 一键配置 cnb↔GitHub 同步

- 智能合并 .cnb/web_trigger.yml（保留已有按钮，追加同步按钮）
- 智能合并 .cnb.yml（追加 include 引用 cnb-sync 流水线）
- 目标 GitHub 仓库: ${GITHUB_REPO:-默认}"

git add .cnb/web_trigger.yml .cnb.yml
git commit -m "$COMMIT_MSG"

echo "📤 推送到目标仓库 ..."
git push origin "$SETUP_BRANCH"

# ============================================================
# 6. 在目标仓库创建 MR
# ============================================================
echo "🔗 在 ${TARGET_SLUG} 创建 MR ..."

# 先测试 API 连通性
echo "   测试 API 连通性..."
API_TEST=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $CNB_TOKEN" \
  "https://api.cnb.cool/v1/repos/${TARGET_SLUG}")
echo "   API 状态码: $API_TEST"

# 尝试使用不同的 API 端点创建 MR
MR_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $CNB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"source_branch\": \"${SETUP_BRANCH}\",
    \"target_branch\": \"main\",
    \"title\": \"feat: 一键配置同步\",
    \"description\": \"一键配置 cnb↔GitHub 同步\\n\\n- 智能合并 .cnb/web_trigger.yml（保留已有按钮，追加同步按钮）\\n- 智能合并 .cnb.yml（追加 include 引用）\\n- 目标 GitHub 仓库: ${GITHUB_REPO:-默认}\"
  }" "https://api.cnb.cool/v1/repos/${TARGET_SLUG}/merge_requests" 2>&1)

MR_HTTP_CODE=$(echo "$MR_RESPONSE" | tail -1)
MR_BODY=$(echo "$MR_RESPONSE" | sed '$d')

echo "   HTTP 状态码: $MR_HTTP_CODE"
echo "   API 响应: $MR_BODY"

if [ "$MR_HTTP_CODE" = "201" ] || [ "$MR_HTTP_CODE" = "200" ]; then
  MR_IID=$(echo "$MR_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['iid'])" 2>/dev/null || echo "?")
  MR_URL=$(echo "$MR_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['web_url'])" 2>/dev/null || echo "https://cnb.cool/${TARGET_SLUG}/-/merge-requests/${MR_IID}")
  echo ""
  echo "✅ MR 创建成功!"
  echo "   https://cnb.cool/${TARGET_SLUG}/-/merge-requests/${MR_IID}"
elif [ "$MR_HTTP_CODE" = "401" ]; then
  echo "❌ 认证失败,请检查 CNB_TOKEN 是否正确"
  exit 1
elif [ "$MR_HTTP_CODE" = "404" ]; then
  echo "❌ API 端点不存在,尝试旧版端点..."
  MR_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $CNB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"source_branch\": \"${SETUP_BRANCH}\",
      \"target_branch\": \"main\",
      \"title\": \"feat: 一键配置同步\",
      \"description\": \"一键配置 cnb↔GitHub 同步\"
    }" "https://api.cnb.cool/${TARGET_SLUG}/-/merge-requests" 2>&1)
  echo "   旧版响应: $MR_RESPONSE"
  exit 1
else
  echo "❌ MR 创建失败 (HTTP $MR_HTTP_CODE): $MR_BODY"
  exit 1
fi
