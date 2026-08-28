# Issue 跟踪器：本地 Markdown

本仓库的 issue 和规格文档（spec，你可能称之为 PRD）以 Markdown 文件形式存放于 `.scratch/` 目录下。

## 约定

- 每个功能一个目录：`.scratch/<feature-slug>/`
- 规格文档为：`.scratch/<feature-slug>/spec.md`
- 实现 issue 每个 ticket 一个文件：`.scratch/<feature-slug>/issues/<NN>-<slug>.md`，从 `01` 开始编号——绝不使用单个合并的 tickets 文件
- 分类状态记录为每个 issue 文件顶部附近的 `Status:` 行（角色字符串参见 `triage-labels.md`）
- 评论和对话历史追加到文件底部的 `## Comments` 标题下

## 当某个 skill 说"发布到 issue 跟踪器"时

在 `.scratch/<feature-slug>/` 下创建新文件（如需则创建目录）。

## 当某个 skill 说"获取相关 ticket"时

读取所引用路径的文件。用户通常会直接传入路径或 issue 编号。

## 导航操作（Wayfinding operations）

由 `/wayfinder` 使用。**地图（map）** 是一个包含多个**子（child）** ticket 文件的文件。

- **地图**：`.scratch/<effort>/map.md` ——包含备注（Notes）/ 已做决策（Decisions-so-far）/ 待探索区（Fog）正文。
- **子 ticket**：`.scratch/<effort>/issues/NN-<slug>.md`，从 `01` 开始编号，正文中包含问题描述。`Type:` 行记录 ticket 类型（`research`/`prototype`/`grilling`/`task`）；`Status:` 行记录 `claimed`/`resolved`。
- **阻塞关系**：文件顶部附近的 `Blocked by: NN, NN` 行。当所列出的每个文件都为 `resolved` 时，该 ticket 即解除阻塞。
- **前沿（Frontier）**：扫描 `.scratch/<effort>/issues/` 查找处于开放、未阻塞、未认领状态的文件；编号最小者优先。
- **认领（Claim）**：在开始任何工作前，将 `Status:` 设为 `claimed` 并保存。
- **解决（Resolve）**：在 `## Answer` 标题下追加答案，将 `Status:` 设为 `resolved`，然后向 `map.md` 的"已做决策"部分追加一个上下文指针（gist + 链接）。
