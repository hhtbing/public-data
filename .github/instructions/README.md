# VS Code 规则系统说明

本目录包含 VS Code Copilot 的自定义指令文件。

## 📁 目录结构

```
.github/
├── copilot-instructions.md          # 核心工作原则（自动应用）
└── instructions/                     # 具体规则指令
    ├── file-operations.instructions.md
    ├── directory-management.instructions.md
    ├── naming-conventions.instructions.md
    └── emoji-style.instructions.md
```

## 🎯 规则说明

### 核心规则文件
- **copilot-instructions.md**: 包含最高优先级的核心原则，自动应用于所有对话

### 指令文件（.instructions.md）
每个指令文件都使用 YAML frontmatter 定义其行为：

```yaml
---
description: "规则描述"
applyTo: "**"              # Glob 模式，定义应用范围
---
```

## 📋 现有规则

| 文件 | 描述 | 应用范围 | 优先级 |
|------|------|----------|--------|
| `00-encoding-protection.instructions.md` | 🔴🔴🔴 **编码保护v3.0 - 最高优先级强制执行** | 所有文件 | **0 - 最高** |
| `file-reading.instructions.md` | 🔴🔴🔴 **严禁AI偷懒不读文件** | 所有文件 | **1 - 极高** |
| `file-operations.instructions.md` | 文件操作强制规则 | 所有文件 | 高 |
| `directory-management.instructions.md` | 目录结构管理 | 所有文件 | 高 |
| `naming-conventions.instructions.md` | 文件命名标准 | 所有文件 | 中 |
| `git-operations.instructions.md` | Git操作规范 | 所有文件 | 高 |
| `task-verification.instructions.md` | 任务完成验证规则 | 所有文件 | 高 |
| `encoding-check.instructions.md` | 编码检查规则 | 所有文件 | 高 |
| `emoji-style.instructions.md` | Markdown 文档风格 | 所有 .md 文件 | 低 |

## 🔄 与 Windsurf 规则的关系

本规则系统从 `.windsurf/rules/` 转换而来，保持规则内容一致：

| Windsurf 规则 | VS Code 规则 |
|--------------|-------------|
| `00-核心工作原则.md` | `copilot-instructions.md` |
| `01-文件操作规范.md` | `file-operations.instructions.md` |
| `02-目录管理规范.md` | `directory-management.instructions.md` |
| `03-文件命名规范.md` | `naming-conventions.instructions.md` |
| `06-Git操作规范.md` | `git-operations.instructions.md` |
| `07-Emoji文档风格规范.md` | `emoji-style.instructions.md` |
| **新增** | `file-reading.instructions.md` ⭐ |

> ⭐ **最新规则**：`file-reading.instructions.md` 是从实际案例中提炼的最高优先级规则，用于防止AI偷懒不读文件就瞎推测。

## ⚙️ 配置

在 VS Code 设置中启用：

```json
{
  "github.copilot.chat.codeGeneration.useInstructionFiles": true
}
```

## 📚 更多信息

详细的规则内容和使用说明请参考：
- [VS Code 自定义指令文档](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)
- 项目根目录的 `README.md`
- `.windsurf/README.md`（原始规则系统说明）
