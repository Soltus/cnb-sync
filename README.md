# cnb-sync — cnb.cool 通用同步模板

通用 cnb.cool ↔ GitHub 双向同步方案，可被任意 cnb 仓库通过 import 引用。

## 功能

- 🚀 一键推送 cnb → GitHub
- 📥 一键拉取 GitHub → cnb
- 🔄 双向同步
- 🎛️ 支持参数化（指定分支、预览模式）

## 使用方法

在你的 `.cnb.yml` 中引用：

```yaml
include:
  - https://cnb.cool/sc.hwd/cnb-sync/-/blob/main/.cnb/workflows/sync.yml
```

并在 `.cnb/web_trigger.yml` 中引用按钮定义：

```yaml
$:
  imports:
    - "https://cnb.cool/sc.hwd/cnb-sync/-/blob/main/.cnb/web_trigger.yml"
```

## 前置条件

1. 在 secrets 仓库中配置 `GITHUB_TOKEN` 环境变量
2. 确保 cnb 仓库中有 `scripts/cnb-sync.sh`（会自动引用）

## 文件结构

```
cnb-sync/
├── .cnb/
│   ├── web_trigger.yml       # 按钮定义
│   └── workflows/
│       └── sync.yml          # 流水线逻辑
├── scripts/
│   └── cnb-sync.sh           # 通用同步脚本
└── README.md
```
