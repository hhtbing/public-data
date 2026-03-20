# 中文编码问题解决方案

> 本文档详细记录了项目中处理中文编码（乱码/崩溃）问题的完整解决方案。
> 适用于：Node.js、HTML、JavaScript、Markdown 等文件类型。

## 🔴 核心问题

**问题现象**：
- 中文字符显示为乱码（如 `ä¸­æ–‡` 或 `???`）
- 文件包含 BOM（Byte Order Mark）导致解析失败
- PowerShell/Windows 终端输出中文乱码
- 代码中的中文注释/字符串引发编译或运行时错误

**根本原因**：
- 文件编码不一致（UTF-8 vs GBK/GB2312）
- BOM 头干扰（UTF-8 with BOM vs UTF-8 without BOM）
- 终端/控制台编码设置不正确
- 编辑器自动检测编码失败

---

## ✅ 解决方案

### 1. Node.js 文件读写

**读取文件时**：
```javascript
// 🔴 正确方式：读取为 Buffer，然后转 UTF-8，移除 BOM
const buffer = fs.readFileSync(filePath);
let content = buffer.toString('utf8');

// 移除 BOM（如果存在）
if (content.charCodeAt(0) === 0xFEFF) {
    content = content.slice(1);
}
```

**写入文件时**：
```javascript
// 🔴 写入时显式使用 UTF-8 无 BOM 编码
fs.writeFileSync(filePath, content, { encoding: 'utf8', flag: 'w' });
```

**验证写入**：
```javascript
// 🔴 验证写入内容，检测乱码
const verification = fs.readFileSync(filePath, 'utf8');
const hasMojibake = /\uFFFD/.test(verification);
if (hasMojibake) {
    console.warn(`⚠️ 警告: ${filePath} 可能包含乱码字符`);
}
```

---

### 2. Node.js 进程编码设置

在脚本开头添加：
```javascript
// 🔴 强制设置 Node.js 使用 UTF-8 编码
process.env.NODE_OPTIONS = '--no-warnings';
if (process.stdout) process.stdout.setDefaultEncoding('utf8');
if (process.stderr) process.stderr.setDefaultEncoding('utf8');
```

---

### 3. HTML 文件

**必须**在 `<head>` 的第一行声明编码：
```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <!-- 其他 meta 标签... -->
</head>
```

---

### 4. 编辑器配置

**VS Code settings.json**：
```json
{
    "files.encoding": "utf8",
    "files.autoGuessEncoding": false,
    "[markdown]": {
        "files.encoding": "utf8"
    },
    "[html]": {
        "files.encoding": "utf8"
    },
    "[javascript]": {
        "files.encoding": "utf8"
    }
}
```

**.editorconfig**：
```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 4

[*.md]
trim_trailing_whitespace = false
```

---

### 5. Git 配置

防止 Git 自动转换编码：
```bash
git config --global core.autocrlf false
git config --global core.quotepath false
git config --global i18n.commitencoding utf-8
git config --global i18n.logoutputencoding utf-8
```

**.gitattributes**：
```
* text=auto eol=lf
*.html text eol=lf
*.css text eol=lf
*.js text eol=lf
*.json text eol=lf
*.md text eol=lf
```

---

### 6. PowerShell/Windows 终端

**临时设置**：
```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001
```

**永久设置**（添加到 PowerShell Profile）：
```powershell
# 编辑 Profile
notepad $PROFILE

# 添加以下内容
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
```

---

### 7. Docker 容器

**Dockerfile**：
```dockerfile
# 设置环境变量
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV NODE_OPTIONS=--no-warnings
```

---

## 🛡️ 自动阻止乱码提交到 GitHub（3种方案）

### 方案1：Git Pre-commit Hook（推荐）

在 `.git/hooks/pre-commit` 创建脚本，自动检测并阻止乱码文件提交：

**创建 Hook 脚本**：
```bash
#!/bin/bash
# .git/hooks/pre-commit - 检测乱码并阻止提交

echo "🔍 检查文件编码..."

# 检测乱码的正则模式（常见乱码特征）
MOJIBAKE_PATTERNS=(
    "ä¸­"      # 中 的乱码
    "æ–‡"      # 文 的乱码
    "ã€"       # 、的乱码
    "â€"       # 引号乱码
    "Ã©"       # é 的乱码
    "Ã¨"       # è 的乱码
    $'\xEF\xBF\xBD'  # Unicode 替换字符 U+FFFD
)

HAS_MOJIBAKE=0
PROBLEMATIC_FILES=""

# 获取暂存的文件
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(html|js|css|md|json|txt)$')

for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        for pattern in "${MOJIBAKE_PATTERNS[@]}"; do
            if grep -q "$pattern" "$file" 2>/dev/null; then
                HAS_MOJIBAKE=1
                PROBLEMATIC_FILES="$PROBLEMATIC_FILES\n  ❌ $file (包含乱码: $pattern)"
                break
            fi
        done
    fi
done

if [ $HAS_MOJIBAKE -eq 1 ]; then
    echo ""
    echo "🚫 检测到乱码文件，提交被阻止！"
    echo -e "$PROBLEMATIC_FILES"
    echo ""
    echo "💡 解决方法："
    echo "   1. 检查文件编码是否为 UTF-8（无 BOM）"
    echo "   2. 使用 VS Code 重新保存文件（选择 UTF-8 编码）"
    echo "   3. 运行：git diff --cached <file> 查看差异"
    echo ""
    exit 1
fi

echo "✅ 编码检查通过"
exit 0
```

**Windows PowerShell 版本**（保存为 `.git/hooks/pre-commit`，无扩展名）：
```powershell
#!/usr/bin/env pwsh
# Git pre-commit hook - 检测乱码

$ErrorActionPreference = "Stop"

Write-Host "🔍 检查文件编码..." -ForegroundColor Cyan

# 乱码特征模式
$mojibakePatterns = @(
    'ä¸­', 'æ–‡', 'ã€', 'â€', 'Ã©', 'Ã¨', 'ï¼'
)

$stagedFiles = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -match '\.(html|js|css|md|json)$' }

$hasError = $false
foreach ($file in $stagedFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        foreach ($pattern in $mojibakePatterns) {
            if ($content -match [regex]::Escape($pattern)) {
                Write-Host "❌ $file 包含乱码: $pattern" -ForegroundColor Red
                $hasError = $true
                break
            }
        }
    }
}

if ($hasError) {
    Write-Host "`n🚫 检测到乱码，提交被阻止！" -ForegroundColor Red
    Write-Host "💡 请检查文件编码是否为 UTF-8（无 BOM）" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ 编码检查通过" -ForegroundColor Green
exit 0
```

---

### 方案2：GitHub Actions 自动检测

在 `.github/workflows/encoding-check.yml` 创建工作流：

```yaml
name: Encoding Check

on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main]

jobs:
  check-encoding:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Check for mojibake (garbled text)
        run: |
          echo "🔍 Checking for encoding issues..."
          
          MOJIBAKE_FOUND=0
          
          # 常见乱码模式
          PATTERNS="ä¸­|æ–‡|ã€|â€|Ã©|Ã¨"
          
          # 检查所有文本文件
          for file in $(find . -type f \( -name "*.html" -o -name "*.js" -o -name "*.css" -o -name "*.md" \) -not -path "./.git/*"); do
            if grep -qE "$PATTERNS" "$file" 2>/dev/null; then
              echo "❌ Mojibake detected in: $file"
              grep -nE "$PATTERNS" "$file" | head -5
              MOJIBAKE_FOUND=1
            fi
          done
          
          # 检查 UTF-8 BOM
          for file in $(find . -type f \( -name "*.html" -o -name "*.js" -o -name "*.css" \) -not -path "./.git/*"); do
            if head -c 3 "$file" | grep -q $'\xEF\xBB\xBF'; then
              echo "⚠️ UTF-8 BOM detected in: $file"
            fi
          done
          
          if [ $MOJIBAKE_FOUND -eq 1 ]; then
            echo ""
            echo "🚫 Encoding check failed! Please fix the garbled text."
            exit 1
          fi
          
          echo "✅ All files passed encoding check"
```

---

### 方案3：VS Code 任务自动检测

在 `.vscode/tasks.json` 添加编码检测任务：

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Check Encoding",
            "type": "shell",
            "command": "powershell",
            "args": [
                "-Command",
                "$patterns = @('ä¸­', 'æ–‡', 'ã€', 'â€'); $files = Get-ChildItem -Recurse -Include *.html,*.js,*.css,*.md | Where-Object { $_.FullName -notmatch '\\.git' }; $errors = @(); foreach ($f in $files) { $c = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue; foreach ($p in $patterns) { if ($c -match [regex]::Escape($p)) { $errors += \"❌ $($f.Name): 包含乱码 '$p'\"; break } } }; if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }; Write-Host \"`n🚫 发现 $($errors.Count) 个文件有乱码问题\" -ForegroundColor Red; exit 1 } else { Write-Host '✅ 所有文件编码正常' -ForegroundColor Green }"
            ],
            "problemMatcher": [],
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            },
            "runOptions": {
                "runOn": "folderOpen"
            }
        }
    ]
}
```

---

### 🔧 快速部署指南

**一键部署 Pre-commit Hook（推荐）**：

```powershell
# Windows PowerShell - 创建 pre-commit hook
$hookPath = ".git/hooks/pre-commit"
$hookContent = @'
#!/usr/bin/env pwsh
$patterns = @('ä¸­', 'æ–‡', 'ã€', 'â€', 'ï¼')
$files = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -match '\.(html|js|css|md)$' }
$hasError = $false
foreach ($f in $files) {
    if (Test-Path $f) {
        $c = Get-Content $f -Raw -ErrorAction SilentlyContinue
        foreach ($p in $patterns) {
            if ($c -match [regex]::Escape($p)) {
                Write-Host "❌ $f 包含乱码" -ForegroundColor Red
                $hasError = $true
                break
            }
        }
    }
}
if ($hasError) { Write-Host "🚫 提交被阻止" -ForegroundColor Red; exit 1 }
Write-Host "✅ 编码检查通过" -ForegroundColor Green
'@
$hookContent | Out-File -FilePath $hookPath -Encoding utf8 -Force
Write-Host "✅ Pre-commit hook 已创建" -ForegroundColor Green
```

---

## 📋 检查清单

在提交代码前，请确认：

- [ ] 所有文件使用 UTF-8 编码（无 BOM）
- [ ] HTML 文件包含 `<meta charset="UTF-8">`
- [ ] Node.js 读取文件时处理 BOM
- [ ] Node.js 写入文件时显式指定 UTF-8
- [ ] .editorconfig 配置正确
- [ ] .gitattributes 配置正确
- [ ] **Pre-commit Hook 已部署**（自动阻止乱码）

---

## 🔧 常用工具

### 检测文件编码
```powershell
# PowerShell
[System.IO.File]::ReadAllBytes("file.txt")[0..2] -join ","
# UTF-8 BOM: 239,187,191
# 无 BOM: 其他值

# Linux/Mac
file -bi filename.txt
```

### 批量转换编码
```powershell
# 使用 iconv (需安装)
iconv -f GBK -t UTF-8 input.txt > output.txt

# Node.js 脚本
node -e "
const fs = require('fs');
const iconv = require('iconv-lite');
const buffer = fs.readFileSync('input.txt');
const content = iconv.decode(buffer, 'gbk');
fs.writeFileSync('output.txt', content, 'utf8');
"
```

---

## 📚 参考资料

- [Node.js Buffer 文档](https://nodejs.org/api/buffer.html)
- [UTF-8 BOM 问题](https://en.wikipedia.org/wiki/Byte_order_mark)
- [VS Code 编码设置](https://code.visualstudio.com/docs/editor/codebasics#_file-encoding-support)

---

## 📅 更新历史

| 日期 | 更新内容 |
|------|----------|
| 2026-01-24 | 初版创建，整理项目中的编码处理方案 |
