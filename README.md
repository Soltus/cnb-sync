# cnb-sync — cnb.cool 通用同步模板

通用 cnb.cool ↔ GitHub 双向同步方案，可被任意 cnb 仓库通过 `include` 引用。

## 功能

- 🚀 一键推送 cnb → GitHub
- 📥 一键拉取 GitHub → cnb
- 🔄 双向同步
- 🎛️ 支持参数化（指定分支、预览模式、强制覆盖、自定义 GitHub 仓库）

## 使用方法

在你的 `.cnb.yml` 中添加：

```yaml
include:
  - https://cnb.cool/sc.hwd/cnb-sync/-/blob/main/.cnb/workflows/sync.yml
```

然后在仓库本地创建 `.cnb/web_trigger.yml` 文件（**不支持 include，必须本地存在**），内容参考本仓库的 `.cnb/web_trigger.yml`。

## 前置条件

1. 在 secrets 仓库中配置 `GITHUB_TOKEN`，并通过 `imports` 引入到流水线
2. 确保 secrets 仓库的 `allow_slugs` 包含引用仓库（如 `"sc.hwd/cnb-sync"`）

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
│   ├── web_trigger.yml       # 按钮定义（⚠️ 必须本地存在，不支持 include）
│   └── workflows/
│       └── sync.yml          # 流水线逻辑（通过 include 引用）
├── scripts/
│   └── cnb-sync.sh           # 通用同步脚本（通过 include 引用）
└── README.md
```
