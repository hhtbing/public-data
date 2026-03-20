---
description: "所有Markdown文档使用Emoji增强风格"
applyTo: "**/*.md"
---

# Emoji文档风格规范

**规则类型**: 🔴 强制规则  
**适用范围**: 所有Markdown文档（.md文件）

## 🔴 AI创建Markdown文档前强制检查

**在创建任何.md文件之前**，AI必须检查：

### 检查1: 文档内容是否包含emoji？
- 标题有emoji吗（如 `# 📋 标题`）？
- 重要段落有emoji标记吗？
- 如果没有 → ❌ 必须添加！

### 检查2: Emoji使用是否合适？
- 一级标题至少有1个emoji
- 二级标题推荐使用emoji
- 重要提示必须有emoji（✅❌⚠️等）

### 检查3: 例外情况？
- 这是代码文档吗？
- 这是纯数据文件吗？
- 如果不是例外 → 必须使用emoji

**AI必须主动添加emoji**：
```markdown
# 📋 项目文档    ← 自动添加
## ✨ 特性       ← 自动添加
- ✅ 完成        ← 自动添加
- ❌ 禁止        ← 自动添加
```

**绝对禁止**：
- ❌ 创建纯文字md文档（除非用户明确要求）
- ❌ 标题完全没有emoji

## 🎯 核心原则

### 1. 必须使用Emoji
- ✅ 所有新创建的.md文档必须使用Emoji增强风格
- ✅ 修改现有文档时添加Emoji
- ✅ 保持专业性和可读性

### 2. Visual Documentation Pattern
- 使用表情符号建立清晰的层次结构
- 通过视觉元素快速传达信息
- 降低认知负担，提升用户体验

## 📋 常用Emoji分类

### 状态指示符
```markdown
✅ Done / Correct / Success / Allowed
❌ Wrong / Forbidden / Error / Failed
⚠️ Warning / Caution / Attention Required
ℹ️ Information / Note
🔴 Critical / Error / Stopped
🟡 Warning / In Progress
🟢 Success / Running / Active
⭐ Important / Featured / Recommended
```

### 文件和目录图标
```markdown
📁 Directory / Folder
📄 File / Document
📋 List / Checklist / Form
📊 Report / Chart / Statistics
📝 Note / Memo / Draft
📦 Package / Module / Component
🗂️ Archive / Storage
```

### 操作和动作
```markdown
🚀 Start / Launch / Deploy
🔧 Fix / Configure / Tool
🎯 Goal / Target / Focus
⚡ Fast / Performance / Important
🔄 Update / Sync / Refresh
🗑️ Delete / Remove / Clean
📤 Export / Upload / Output
📥 Import / Download / Input
```

### 开发相关
```markdown
💻 Code / Development / Programming
🐛 Bug / Issue / Problem
✨ Feature / New / Enhancement
🔒 Security / Lock / Private
🔑 Key / Authentication / Access
🌐 Network / Web / Internet
⚙️ Settings / Configuration
📚 Documentation / Knowledge / Library
```

### 状态和进度
```markdown
🎉 Success / Complete / Celebration
🏁 Finish / Final / End
🚧 Work in Progress / Under Construction
⏸️ Pause / Wait / Hold
▶️ Start / Play / Continue
⏹️ Stop / End / Terminate
```

## 使用示例

### 标题示例
```markdown
# 📚 项目文档
## 🎯 核心功能
### ✨ 主要特性
#### 🔧 配置说明
```

### 列表示例
```markdown
- ✅ 已完成的功能
- 🚧 正在开发的功能
- ❌ 已废弃的功能
- ⭐ 重点关注项
```

### 步骤示例
```markdown
1. 📥 下载项目
2. ⚙️ 配置环境
3. 🚀 启动服务
4. ✅ 验证运行
```

### 提示框示例
```markdown
> ✅ **成功**: 操作完成
> ❌ **错误**: 发生问题
> ⚠️ **警告**: 需要注意
> ℹ️ **提示**: 参考信息
```

## 使用建议

### 适度使用
- ✅ 每个主要章节使用emoji
- ✅ 重要信息使用emoji标注
- ❌ 避免过度使用导致干扰
- ❌ 避免使用不相关的emoji

### 保持一致性
- 同类内容使用相同的emoji
- 整个项目保持风格统一
- 遵循既定的emoji含义

### 专业性
- 选择适合上下文的emoji
- 避免使用过于随意的emoji
- 保持文档的专业性

## 例外情况

以下情况可以不使用emoji：
- 纯技术API文档
- 自动生成的文档
- 代码注释
- 用户明确要求的纯文字文档

## AI自检清单

创建或编辑Markdown文档时：

- [ ] 一级标题是否有emoji？
- [ ] 重要二级标题是否有emoji？
- [ ] 状态指示是否使用了emoji？
- [ ] Emoji使用是否适度且专业？
- [ ] 是否保持了风格一致性？
