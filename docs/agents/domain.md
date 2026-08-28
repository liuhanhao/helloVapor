# 领域文档（Domain Docs）

工程类 skill 在探索代码库时应如何使用本仓库的领域文档。

## 探索前，先阅读以下内容

- 仓库根目录的 **`CONTEXT.md`**，或
- 根目录的 **`CONTEXT-MAP.md`**（如果存在）——它指向每个上下文各自的 `CONTEXT.md`。阅读与当前主题相关的每一个文件。
- **`docs/adr/`** ——阅读涉及你即将修改区域的 ADR（架构决策记录）。在多上下文仓库中，还需检查 `src/<context>/docs/adr/` 中的上下文级决策。

如果上述文件不存在，**静默处理**。不要标记它们的缺失，也不要主动建议创建它们。`/domain-modeling` skill（通过 `/grill-with-docs` 和 `/improve-codebase-architecture` 触达）会在术语或决策真正需要落地时懒创建这些文件。

## 文件结构

单上下文仓库（绝大多数仓库）：

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

多上下文仓库（根目录存在 `CONTEXT-MAP.md`）：

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← 系统级决策
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← 上下文级决策
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## 使用词汇表的术语

当你的输出涉及某个领域概念（在 issue 标题、重构提案、假设或测试名称中），使用 `CONTEXT.md` 中定义的术语。不要使用词汇表明确避免的同义词。

如果你需要的概念尚未出现在词汇表中，这是一个信号——要么你在使用项目中不存在的语言（重新考虑），要么存在真实的空白（记录下来，留给 `/domain-modeling`）。

## 标记 ADR 冲突

如果你的输出与现有 ADR 矛盾，明确指出而不是静默覆盖：

> _与 ADR-0007（事件溯源订单）矛盾——但值得重新讨论，因为……_
