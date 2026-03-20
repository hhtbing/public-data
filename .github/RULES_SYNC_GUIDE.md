# 双格式规则系统维护指南

本文档说明如何维护 Windsurf 和 VS Code 两套规则系统。

## 🎯 设计理念

### 为什么需要两套规则？

1. **Windsurf** (`.windsurf/rules/`)
   - 使用 `trigger` 字段控制激活模式
   - 支持 `always_on`、`manual`、`model_decision`、`glob` 四种模式
   - 文件格式: `NN-规则名.md`

2. **VS Code** (`.github/`)
   - 使用 `applyTo` 字段控制应用范围
   - 核心规则放在 `copilot-instructions.md`
   - 具体规则使用 `.instructions.md` 扩展名

### 核心原则

- ✅ **规则内容保持一致** - 两套系统执行相同的规范
- ✅ **格式独立适配** - 使用各自系统的最佳实践
- ✅ **保持通用性** - 规则可复用到任何项目

## 📋 格式对照表

### Frontmatter 转换

| Windsurf | VS Code | 说明 |
|----------|---------|------|
| `trigger: always_on` | `applyTo: "**"` | 应用于所有文件 |
| `trigger: manual` | 不设置 `applyTo` | 手动引用 |
| `trigger: model_decision` | 不设置 `applyTo` | VS Code 无此功能 |
| `trigger: glob` + `globs: "*.py"` | `applyTo: "*.py"` | 文件模式匹配 |

### 文件名转换

| Windsurf | VS Code |
|----------|---------|
| `00-核心工作原则.md` | `copilot-instructions.md` |
| `01-文件操作规范.md` | `file-operations.instructions.md` |
| `02-目录管理规范.md` | `directory-management.instructions.md` |
| `03-文件命名规范.md` | `naming-conventions.instructions.md` |
| `07-Emoji文档风格规范.md` | `emoji-style.instructions.md` |

## 🔄 同步流程

### 修改 Windsurf 规则时

1. **编辑规则文件**: `.windsurf/rules/NN-规则名.md`
2. **确定对应的 VS Code 文件**: 参考上面的对照表
3. **同步内容变更**:
   ```bash
   # 复制规则内容（不包括 frontmatter）
   # 调整 frontmatter 格式
   ```
4. **验证**: 检查两边规则内容一致

### 修改 VS Code 规则时

1. **编辑规则文件**: `.github/instructions/*.instructions.md`
2. **确定对应的 Windsurf 文件**: 参考上面的对照表
3. **同步内容变更**: 同上
4. **验证**: 检查两边规则内容一致

### 添加新规则

#### 在 Windsurf 添加
1. 创建 `.windsurf/rules/NN-新规则.md`
2. 添加适当的 frontmatter
3. 创建对应的 VS Code 指令文件

#### 在 VS Code 添加
1. 创建 `.github/instructions/new-rule.instructions.md`
2. 添加适当的 frontmatter
3. 创建对应的 Windsurf 规则文件

## 🛠️ 转换工具示例

### Python 脚本示例

```python
def convert_windsurf_to_vscode(windsurf_file, vscode_file):
    """转换 Windsurf 规则到 VS Code 格式"""
    with open(windsurf_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 解析 frontmatter
    # 转换 trigger 到 applyTo
    # 写入新文件
    pass

def convert_vscode_to_windsurf(vscode_file, windsurf_file):
    """转换 VS Code 规则到 Windsurf 格式"""
    # 类似的转换逻辑
    pass
```

## ✅ 检查清单

### 同步后必须验证

- [ ] 规则内容完全一致（除了 frontmatter）
- [ ] Frontmatter 格式正确
- [ ] 文件名符合各自系统规范
- [ ] 两边都能正常加载
- [ ] README 文件已更新

### 定期检查

- [ ] 每月检查一次规则一致性
- [ ] 新增规则时确保两边都创建
- [ ] 修改规则时确保两边都同步

## 📚 参考资料

### Windsurf 规则系统
- 位置: `.windsurf/rules/`
- 说明: `.windsurf/README.md`
- Frontmatter 字段: `trigger`, `description`

### VS Code 规则系统
- 位置: `.github/instructions/`
- 说明: `.github/instructions/README.md`
- Frontmatter 字段: `description`, `applyTo`, `name`
- 官方文档: [VS Code 自定义指令](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)

## 🎓 最佳实践

1. **单一真相源**: 选择一个系统作为主要编辑点
2. **及时同步**: 修改后立即同步到另一个系统
3. **版本控制**: 使用 Git 跟踪所有变更
4. **文档化**: 在 commit 信息中说明同步了哪些规则
5. **定期审查**: 每月检查规则的有效性和一致性

## 🚀 未来改进

- [ ] 创建自动同步脚本
- [ ] 添加 CI/CD 检查规则一致性
- [ ] 开发规则编辑器工具
- [ ] 支持更多编辑器格式

---

**记住**: 保持两套系统同步是确保规则有效性的关键！
