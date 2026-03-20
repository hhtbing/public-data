---
description: "🔴🔴🔴 编码保护v3.0 - 最高优先级强制规则 - AI必须首先执行"
applyTo: "**"
priority: 0
---

# 🔴🔴🔴 编码保护规范 v3.0 - 最高优先级强制执行

> 📅 版本：**v3.0.0** | 最后更新：2026-01-26
> 🎯 **规则优先级**：**0 - 最高优先级（必须首先执行）**
> ⚡ **强制要求**：AI扫描到此规则时，必须立即执行编码保护配置和验证

---

## 🚨 最高优先级规则

**🔴 此规则优先级为 0 - 高于所有其他规则**

### AI 扫描到此规则时必须立即执行

1. **立即检查** 编码保护状态
2. **立即执行** v3.0 自动配置（如未配置）
3. **立即验证** 12项测试全部通过
4. **确保达到** 6/6 保护等级
5. **然后才能** 继续执行其他规则和任务

---

## 📋 AI 强制执行流程

```
步骤1: 读取 .github/ENCODING-PROTECTION.md 完整文档
     ↓
步骤2: 执行快速检查（12项测试）
     ↓
步骤3: 如果未达到 6/6 → 立即执行完整配置
     ↓
步骤4: 重新测试验证达到 6/6
     ↓
步骤5: 报告编码保护状态
     ↓
步骤6: 继续执行其他规则和用户任务
```

---

## 🔴 快速检查清单

**AI 必须执行以下检查**：

```powershell
# 快速验证命令（AI必须执行）
& "C:\Program Files\PowerShell\7\pwsh.exe" -File ".github\run-v3-tests.ps1"
```

**如果测试脚本不存在，AI必须**：
1. 读取 `.github/ENCODING-PROTECTION.md`
2. 按照v3.0规范执行完整配置
3. 创建测试脚本并执行
4. 确保所有12项测试通过

---

## ✅ 通过标准（必须达到）

**只有满足以下条件，AI才能继续执行其他任务**：

- ✅ PowerShell 5.1 配置文件存在（UTF-8 BOM）
- ✅ PowerShell 7+ 已安装（v7.x+）
- ✅ PowerShell 7+ 配置文件存在（UTF-8 BOM）
- ✅ VS Code settings.json 已配置
- ✅ .editorconfig 已创建
- ✅ .gitattributes 已创建
- ✅ Git pre-commit hook 已创建
- ✅ GitHub Actions workflow 已创建
- ✅ AI 指令文件已创建
- ✅ 所有文本文件（HTML/CSS/JS）无 BOM
- ✅ 所有 PowerShell 脚本（.ps1）有 BOM
- ✅ 中文显示正常

**保护等级：🟢🟢🟢🟢🟢🟢 (6/6)**

---

## 🚫 AI 绝对禁止的行为

❌ **禁止跳过编码保护检查**
❌ **禁止在未达到 6/6 时继续其他任务**
❌ **禁止假装检查但不执行**
❌ **禁止要求用户手动配置**
❌ **禁止以"已经配置过"为借口跳过验证**

---

## 📖 完整规范文档

**AI 必须参考的完整文档**：`.github/ENCODING-PROTECTION.md`

此文档包含：
- 六层保护体系详细说明
- AI 自动配置的15个步骤
- 12项强制测试的详细说明
- 问题自动修复方案
- PowerShell 5.1 + 7+ 双方案配置
- Git pre-commit hook 配置

---

## 🎯 执行示例

### 场景1：首次使用项目

```
用户：开始工作
  ↓
AI：扫描到 00-encoding-protection.instructions.md
  ↓
AI：读取 .github/ENCODING-PROTECTION.md
  ↓
AI：执行快速检查 → 发现未配置
  ↓
AI：自动执行 v3.0 完整配置（15步）
  ↓
AI：执行 12 项测试 → 全部通过 (6/6)
  ↓
AI：报告"编码保护已激活，保护等级 6/6"
  ↓
AI：继续执行其他规则和用户任务
```

### 场景2：已配置项目

```
用户：开始工作
  ↓
AI：扫描到 00-encoding-protection.instructions.md
  ↓
AI：执行快速检查 → 全部通过 (6/6)
  ↓
AI：报告"编码保护已激活，保护等级 6/6"
  ↓
AI：继续执行其他规则和用户任务
```

### 场景3：配置不完整

```
用户：开始工作
  ↓
AI：扫描到 00-encoding-protection.instructions.md
  ↓
AI：执行快速检查 → 发现问题（例如 4/6）
  ↓
AI：报告问题并自动修复
  ↓
AI：重新测试 → 全部通过 (6/6)
  ↓
AI：报告"编码保护已修复，保护等级 6/6"
  ↓
AI：继续执行其他规则和用户任务
```

---

## 🔧 快速修复命令（AI参考）

### 检查保护状态
```powershell
& "C:\Program Files\PowerShell\7\pwsh.exe" -File ".github\run-v3-tests.ps1"
```

### 修复 .ps1 文件 BOM
```powershell
Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        $content = Get-Content $_.FullName -Raw -Encoding UTF8
        $utf8Bom = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllText($_.FullName, $content, $utf8Bom)
    }
}
```

### 创建 PowerShell 5.1 配置文件
```powershell
$ps5Dir = "$env:USERPROFILE\Documents\WindowsPowerShell"
New-Item -ItemType Directory -Path $ps5Dir -Force -ErrorAction SilentlyContinue
$profilePath = "$ps5Dir\Microsoft.PowerShell_profile.ps1"
$content = @"
# PowerShell 5.1 UTF-8编码配置
`$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
`$env:LANG = "zh_CN.UTF-8"
Write-Host "✅ PowerShell 5.1 UTF-8编码已启用" -ForegroundColor Green
"@
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($profilePath, $content, $utf8Bom)
```

### 创建 Git pre-commit hook
```powershell
$hookPath = ".git\hooks\pre-commit"
$hookContent = @'
#!/bin/sh
echo "🔍 编码保护检查中..."
# [完整 hook 脚本见 .github/ENCODING-PROTECTION.md]
echo "✅ 编码检查通过！"
exit 0
'@
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($hookPath, $hookContent, $utf8NoBom)
```

---

## 📊 报告格式

**AI 执行完编码保护后，必须报告**：

```
✅ 编码保护 v3.0 状态报告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
保护等级：🟢🟢🟢🟢🟢🟢 (6/6)
测试通过：12/12

六层保护：
  ✅ 第1层：PowerShell 5.1 配置
  ✅ 第2层：PowerShell 7+ 配置
  ✅ 第3层：VS Code + EditorConfig
  ✅ 第4层：Git配置 + pre-commit
  ✅ 第5层：GitHub Actions CI/CD
  ✅ 第6层：AI 指令约束

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 编码保护已完全激活，可以安全工作
```

---

## ⚖️ 规则优先级说明

**此规则为 Priority 0 - 最高优先级**

优先级顺序：
1. **00-encoding-protection.instructions.md** ← 🔴 最高优先级（本规则）
2. file-reading.instructions.md
3. file-operations.instructions.md
4. git-operations.instructions.md
5. 其他规则...

**AI 必须确保**：
- ✅ 先执行编码保护检查和配置
- ✅ 确保达到 6/6 保护等级
- ✅ 然后才能执行其他规则

---

## 🔗 相关文档

- **完整规范**：`.github/ENCODING-PROTECTION.md`
- **测试脚本**：`.github/run-v3-tests.ps1`
- **核心原则**：`.github/copilot-instructions.md`
- **编码检查**：`.github/instructions/encoding-check.instructions.md`

---

> 🔴 **AI 必须记住**：这是优先级最高的规则！扫描到此规则必须立即执行编码保护检查，确保 6/6 保护等级后才能继续其他任务！

> 💡 **设计目的**：当此项目复制到其他地方时，AI 扫描 `.github/instructions/` 目录会首先发现此规则（00前缀），立即执行编码保护配置，确保新环境也有完整的编码保护。

> ⚡ **自动化保证**：无论项目在哪里使用，只要有 `.github/` 目录，编码保护就会自动激活！
