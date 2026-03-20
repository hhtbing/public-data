# 🔒 编码保护规范 v3.0

> 📅 版本：**v3.0.0** | 最后更新：2026-01-26
> 🎯 目的：**AI全自动配置，双PowerShell方案，六层保护，强制验证**
> 📋 适用范围：所有项目
> ⚡ **v3.0特性**：PowerShell 5.1+7+双方案，Git pre-commit hook，100%自动化

---

## 🚀 v3.0 核心特性

### 关键改进

| 特性                     | v2.0          | v3.0                  |
| ------------------------ | ------------- | --------------------- |
| **PowerShell方案** | ⚠️ 仅7+     | ✅ 5.1+7+双方案       |
| **Git Hook**       | ❌ 缺失       | ✅ pre-commit强制检查 |
| **保护层级**       | ⚠️ 5层      | ✅ 6层完整保护        |
| **安装指南**       | ⚠️ 单独文档 | ✅ 整合本文档         |
| **测试项目**       | ⚠️ 10项     | ✅ 12项全面验证       |

### v3.0 强制要求

🔴 **所有配置必须由AI自动完成，禁止手动操作**
🔴 **PowerShell 5.1和7+必须同时配置（双方案）**
🔴 **所有6层保护必须全部配置**
🔴 **12项测试必须全部通过**
🔴 **保护等级必须达到6/6**

---

## 📊 六层保护体系

```
┌────────────────────────────────────────────────────────────┐
│                  编码保护六层体系 v3.0                      │
├────────────────────────────────────────────────────────────┤
│ 第1层 │ PowerShell 5.1 │ AI自动配置UTF-8 BOM+profile    │
├────────────────────────────────────────────────────────────┤
│ 第2层 │ PowerShell 7+  │ AI自动安装+配置UTF-8+profile   │
├────────────────────────────────────────────────────────────┤
│ 第3层 │ VS Code配置    │ AI自动配置settings+EditorCfg   │
├────────────────────────────────────────────────────────────┤
│ 第4层 │ Git配置        │ AI自动配置gitattr+pre-hook     │
├────────────────────────────────────────────────────────────┤
│ 第5层 │ GitHub Actions │ AI自动配置workflow CI/CD检查   │
├────────────────────────────────────────────────────────────┤
│ 第6层 │ AI指令层       │ AI自动创建encoding指令约束     │
└────────────────────────────────────────────────────────────┘
```

---

## 🤖 AI自动配置完整流程

```
Step 1:  检查环境状态
Step 2:  配置PowerShell 5.1配置文件（方案1-必须）
Step 3:  安装PowerShell 7+（方案2-必须）
Step 4:  配置PowerShell 7+配置文件（方案2-必须）
Step 5:  配置VS Code设置
Step 6:  创建.editorconfig
Step 7:  创建.gitattributes
Step 8:  创建Git pre-commit hook（必须）
Step 9:  创建GitHub Actions workflow
Step 10: 创建AI指令文件
Step 11: 为所有.ps1文件添加UTF-8 BOM
Step 12: 执行完整测试验证（12项）
Step 13: 修复所有失败项
Step 14: 重新测试直到全部通过
Step 15: 报告最终状态（必须6/6）
```

**AI绝对不允许跳过任何步骤！**

---

## 🔴 第1层：PowerShell 5.1配置（方案1-必须执行）

### 1.1 为什么需要配置PowerShell 5.1？

- ✅ Windows系统默认使用PowerShell 5.1
- ✅ 某些系统工具只能在5.1运行
- ✅ 双方案确保兼容性最大化
- ⚠️ 5.1原生不支持UTF-8无BOM，需要BOM才能解析中文

### 1.2 AI必须创建的配置文件

**文件路径**：`~\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

**文件内容**（必须使用UTF-8 BOM编码）：

```powershell
# PowerShell 5.1 UTF-8编码配置
# AI自动生成 - v3.0
# 重要：此文件必须使用UTF-8 BOM编码

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Export-Csv:Encoding'] = 'utf8'

$env:LANG = "zh_CN.UTF-8"
$env:PYTHONIOENCODING = "utf-8"

Write-Host "✅ PowerShell 5.1 UTF-8编码已启用（方案1）" -ForegroundColor Green
```

**AI执行代码**：

```powershell
$ps5Dir = "$env:USERPROFILE\Documents\WindowsPowerShell"
if (-not (Test-Path $ps5Dir)) {
    New-Item -ItemType Directory -Path $ps5Dir -Force
}

$profilePath = "$ps5Dir\Microsoft.PowerShell_profile.ps1"
$content = @"
# PowerShell 5.1 UTF-8编码配置
# AI自动生成 - v3.0

`$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
`$PSDefaultParameterValues['Export-Csv:Encoding'] = 'utf8'

`$env:LANG = "zh_CN.UTF-8"
`$env:PYTHONIOENCODING = "utf-8"

Write-Host "✅ PowerShell 5.1 UTF-8编码已启用（方案1）" -ForegroundColor Green
"@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($profilePath, $content, $utf8Bom)
```

---

## 🔴 第2层：PowerShell 7+安装与配置（方案2-必须执行）

### 2.1 为什么需要PowerShell 7+？

- ✅ 原生支持UTF-8（有无BOM都可以）
- ✅ 性能更好，功能更强
- ✅ 跨平台支持
- ✅ 彻底解决编码问题

### 2.2 AI自动安装PowerShell 7+

**检查是否已安装**：

```powershell
$pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
if (Test-Path $pwshPath) {
    & $pwshPath --version
} else {
    Write-Host "PowerShell 7+未安装，需要安装"
}
```

**AI自动安装**：

```powershell
# 使用Winget安装
winget install --id Microsoft.PowerShell --source winget

# 验证
& "C:\Program Files\PowerShell\7\pwsh.exe" --version
```

### 2.3 AI必须创建的配置文件

**文件路径**：`~\Documents\PowerShell\profile.ps1`

**文件内容**（使用UTF-8 BOM编码）：

```powershell
# PowerShell 7+ UTF-8编码配置
# AI自动生成 - v3.0

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Export-Csv:Encoding'] = 'utf8'

$env:LANG = "zh_CN.UTF-8"
$env:PYTHONIOENCODING = "utf-8"

Write-Host "✅ PowerShell 7+ 已加载，UTF-8编码已启用" -ForegroundColor Green
```

**AI执行代码**：

```powershell
$ps7Dir = "$env:USERPROFILE\Documents\PowerShell"
if (-not (Test-Path $ps7Dir)) {
    New-Item -ItemType Directory -Path $ps7Dir -Force
}

$profilePath = "$ps7Dir\profile.ps1"
$content = @"
# PowerShell 7+ UTF-8编码配置
# AI自动生成 - v3.0

`$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
`$PSDefaultParameterValues['Export-Csv:Encoding'] = 'utf8'

`$env:LANG = "zh_CN.UTF-8"
`$env:PYTHONIOENCODING = "utf-8"

Write-Host "✅ PowerShell 7+ 已加载，UTF-8编码已启用" -ForegroundColor Green
"@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($profilePath, $content, $utf8Bom)
```

---

## 🔴 第3层：VS Code配置（AI自动配置）

### 3.1 settings.json

**文件路径**：`%APPDATA%\Code\User\settings.json`

**必须添加的配置**：

```json
{
    "files.encoding": "utf8",
    "files.eol": "\n",
    "files.autoGuessEncoding": false,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.trimFinalNewlines": true,
    "editorconfig.enable": true,
    "terminal.integrated.defaultProfile.windows": "PowerShell"
}
```

### 3.2 .editorconfig

**文件路径**：项目根目录 `.editorconfig`

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.{js,jsx,ts,tsx,css,html,json,md,py}]
indent_style = space
indent_size = 2

[*.ps1]
charset = utf-8-bom
end_of_line = crlf
indent_style = space
indent_size = 4

[*.{cmd,bat}]
charset = utf-8-bom
end_of_line = crlf

[*.md]
trim_trailing_whitespace = false
```

---

## 🔴 第4层：Git配置（AI自动配置）

### 4.1 .gitattributes

**文件路径**：项目根目录 `.gitattributes`

```gitattributes
* text=auto

*.html text eol=lf
*.css text eol=lf
*.js text eol=lf
*.json text eol=lf
*.md text eol=lf
*.py text eol=lf
*.sh text eol=lf

*.ps1 text eol=crlf
*.cmd text eol=crlf
*.bat text eol=crlf

*.png binary
*.jpg binary
*.gif binary
*.woff binary
*.woff2 binary
*.ttf binary
```

### 4.2 Git pre-commit hook（必须配置）

**文件路径**：`.git/hooks/pre-commit`

```bash
#!/bin/sh
# 编码保护 - Git Pre-Commit Hook v3.0

echo "🔍 编码保护检查中..."

# 检查HTML/CSS/JS是否有BOM
git diff --cached --name-only --diff-filter=ACM | grep -E '\.(html|css|js|json|md)$' | while read file; do
    if [ -f "$file" ]; then
        if head -c 3 "$file" | od -An -tx1 | grep -q "ef bb bf"; then
            echo "  ❌ 包含BOM: $file"
            exit 1
        fi
    fi
done

# 检查.ps1文件是否有BOM
git diff --cached --name-only --diff-filter=ACM | grep -E '\.ps1$' | while read file; do
    if [ -f "$file" ]; then
        if ! head -c 3 "$file" | od -An -tx1 | grep -q "ef bb bf"; then
            echo "  ❌ 缺少BOM: $file"
            exit 1
        fi
    fi
done

echo "✅ 编码检查通过！"
exit 0
```

**AI创建pre-commit hook**：

```powershell
$hooksDir = ".git\hooks"
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force
}

$hookPath = "$hooksDir\pre-commit"
$hookContent = @'
#!/bin/sh
# 编码保护 - Git Pre-Commit Hook v3.0

echo "🔍 编码保护检查中..."

# [完整hook脚本内容]

echo "✅ 编码检查通过！"
exit 0
'@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($hookPath, $hookContent, $utf8NoBom)
```

---

## 🔴 第5层：GitHub Actions（AI自动配置）

**文件路径**：`.github/workflows/encoding-check.yml`

```yaml
name: 编码保护检查

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  encoding-check:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: 检查BOM标记
      run: |
        echo "🔍 检查BOM..."
        # 检查文本文件无BOM
        find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) -exec sh -c '
          if [ "$(head -c 3 "$1" | od -An -tx1 | tr -d " ")" = "efbbbf" ]; then
            echo "❌ $1"
            exit 1
          fi
        ' _ {} \;

        # 检查.ps1文件有BOM
        find . -type f -name "*.ps1" ! -path "*/node_modules/*" -exec sh -c '
          if [ "$(head -c 3 "$1" | od -An -tx1 | tr -d " ")" != "efbbbf" ]; then
            echo "❌ $1"
            exit 1
          fi
        ' _ {} \;

        echo "✅ BOM检查通过"
```

---

## 🔴 第6层：AI指令文件（AI自动创建）

**文件路径**：`.github/instructions/encoding-check.instructions.md`

内容见完整版规范文档。

---

## ✅ 12项强制测试清单

### 测试1: PowerShell 5.1配置文件

```powershell
Test-Path "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
# 期望：True
```

### 测试2: PowerShell 7+版本

```powershell
& "C:\Program Files\PowerShell\7\pwsh.exe" --version
# 期望：7.x.x
```

### 测试3: PowerShell 7+配置文件

```powershell
Test-Path "$env:USERPROFILE\Documents\PowerShell\profile.ps1"
# 期望：True
```

### 测试4: VS Code配置

```powershell
Test-Path "$env:APPDATA\Code\User\settings.json"
# 期望：True
```

### 测试5: .editorconfig

```powershell
Test-Path ".editorconfig"
# 期望：True
```

### 测试6: .gitattributes

```powershell
Test-Path ".gitattributes"
# 期望：True
```

### 测试7: Git pre-commit hook

```powershell
Test-Path ".git\hooks\pre-commit"
# 期望：True
```

### 测试8: GitHub Actions

```powershell
Test-Path ".github\workflows\encoding-check.yml"
# 期望：True
```

### 测试9: AI指令文件

```powershell
Test-Path ".github\instructions\encoding-check.instructions.md"
# 期望：True
```

### 测试10: HTML/CSS/JS无BOM

```powershell
# 检查所有文本文件无BOM
```

### 测试11: .ps1文件有BOM

```powershell
# 检查所有PowerShell脚本有BOM
```

### 测试12: 中文显示

```powershell
Write-Host "测试中文: ✅ 编码保护系统"
# 期望：正常显示
```

---

## 📊 保护等级标准

### 6/6 完全保护 🟢🟢🟢🟢🟢🟢（强制要求）

- ✅ PowerShell 5.1配置完成
- ✅ PowerShell 7+安装并配置
- ✅ VS Code配置完成
- ✅ .editorconfig已创建
- ✅ .gitattributes已创建
- ✅ Git pre-commit hook已配置
- ✅ GitHub Actions已配置
- ✅ AI指令文件已创建
- ✅ 12项测试全部通过

### 5/6以下 = 配置失败 ❌

任何低于6/6的结果都视为失败！

---

## 🛠️ AI自动修复方案

### 修复.ps1文件缺BOM

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

### 修复HTML/CSS/JS有BOM

```powershell
Get-ChildItem -Recurse -Include *.html,*.css,*.js | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        [System.IO.File]::WriteAllBytes($_.FullName, $bytes[3..($bytes.Length-1)])
    }
}
```

---

> 🔴 **AI严禁偷懒**：不允许跳过任何步骤、不允许跳过任何测试、不允许报告低于6/6的保护等级！

> 🤖 **AI必须记住**：PowerShell 5.1和7+都要配置（双方案），pre-commit hook必须创建，12项测试必须全部通过，保护等级必须6/6！

---

**版本历史**：

- v1.0.0 - 手动配置
- v2.0.0 - AI自动化，5层保护
- v3.0.0 - 双PowerShell方案，6层保护，整合安装指南，强制6/6保护等级
