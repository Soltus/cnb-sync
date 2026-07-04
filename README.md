# cnb-sync — cnb.cool 通用同步模板

通用 cnb.cool ↔ GitHub 双向同步方案，可被任意 cnb 仓库通过 `include` 引用。

## ✨ 新功能：一键配置同步

**现已支持通过按钮一键完成全部配置并自动创建 Merge Request！**

只需点击"⚙️ 一键配置同步"按钮，系统将自动：

1. 在目标仓库创建 `.cnb/web_trigger.yml`（含所有同步按钮）
2. 智能合并 `.cnb.yml`（追加 include 引用，保留原有注释）
3. 复制 `scripts/cnb-sync.sh` 同步脚本
4. 创建分支并提交更改
5. **自动创建 Merge Request**

> ⚠️ **旧的手动复制文件流程已废弃！** 不再需要手动创建文件、手动编辑、手动创建 MR。

## 功能

- 🚀 一键推送 cnb → GitHub
- 📥 一键拉取 GitHub → cnb
- 🔄 双向同步
- ⚙️ **一键配置同步**（自动写入配置 + 自动创建 MR）
- 🎛️ 支持参数化（指定分支、预览模式、强制覆盖、自定义 GitHub 仓库）

## 使用方法

### 方式一：一键配置（推荐）

1. 在仓库中点击"⚙️ 一键配置同步"按钮
2. 输入目标仓库名（如 `sono`）
3. 等待自动创建 MR 并合并即可

### 方式二：手动配置（已废弃，仅供参考）

~~在 `.cnb.yml` 中添加 include~~ → **请使用一键配置按钮代替**

~~手动创建 `.cnb/web_trigger.yml`~~ → **一键配置自动生成**

~~手动复制 `scripts/cnb-sync.sh`~~ → **一键配置自动复制**

## 前置条件

1. 在 secrets 仓库中配置 `GITHUB_TOKEN`，并通过 `imports` 引入到流水线
2. 确保 secrets 仓库的 `allow_slugs` 包含引用仓库（如 `"sc.hwd/cnb-sync"`）
3. 目标仓库需要有适当的权限（CNB_TOKEN 具有写入权限）

## 按钮参数说明

| 参数 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| `mode` | select | 同步范围：当前分支 / 全部分支 | `current` |
| `branch` | input | 指定分支名（当前分支模式下可留空） | 留空 |
| `force` | switch | 是否使用 `--force` 推送 | 关闭 |
| `github_repo` | input | 目标 GitHub 仓库地址（如 `owner/repo`） | 留空（同 cnb 仓库名） |
| `dry_run` | select | 预览模式：true=预览不执行，false=直接执行 | `false` |

## 文件结构

```
cnb-sync/
├── .cnb/
│   ├── web_trigger.yml       # 按钮定义示例（⚠️ 必须本地存在，不支持 include）
│   └── workflows/
│       └── sync.yml          # 流水线逻辑（通过 include 引用）
├── scripts/
│   ├── cnb-sync.sh           # 通用同步脚本
│   └── auto-setup-sync.sh    # 一键配置脚本
└── README.md
```

## 工作流程

```
用户点击按钮
    ↓
触发 sync.yml 中的 web_trigger_* 事件
    ↓
执行对应的同步脚本 (cnb-sync.sh)
    ↓
推送/拉取代码到 GitHub
    ↓
完成同步
```

## 常见问题

### Q: 一键配置失败怎么办？

A: 如果 MR 自动创建失败，分支已经推送成功，请手动访问提示的链接创建 MR。

### Q: 可以自定义 GitHub 仓库吗？

A: 可以，在按钮参数中输入 `github_repo`（格式：`owner/repo`）。

### Q: 如何预览同步效果？

A: 点击"🔄 双向同步"按钮时选择"预览模式"，不会实际执行推送。
