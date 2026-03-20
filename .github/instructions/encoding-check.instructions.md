---
description: "AI 编码检查规则 - 防止生成乱码代码"
applyTo: "**"
---

# 🔒 AI 编码检查规则

**规则类型**: 🔴 强制规则  
**强制级别**: 🔴 严格执行  
**适用范围**: 所有文件操作

---

## 🎯 核心原则

**AI 在创建或修改任何文件时，必须确保编码正确，防止乱码导致工作白费。**

---

## ✅ 强制规则

### 1. 文件编码

- ✅ **所有文件必须使用 UTF-8 编码**
- ❌ 禁止使用 GBK、GB2312、ISO-8859-1 等其他编码
- ❌ 禁止在 UTF-8 文件中添加 BOM（Byte Order Mark）

### 2. 换行符

- ✅ **所有文本文件使用 LF（Unix 风格）换行符**
- ❌ 禁止使用 CRLF（Windows 风格）
- ⚠️ **例外**：`.cmd`、`.bat`、`.ps1` 文件可以使用 CRLF

### 3. 中文内容

- ✅ 中文内容必须正确编码，无乱码
- ✅ 注释、字符串中的中文需验证显示正确
- ❌ 禁止使用 Unicode 转义序列代替中文（除非技术上必要）

**正确示例**：
```javascript
// 这是中文注释
const message = "欢迎使用";
```

**错误示例**：
```javascript
// \u8fd9\u662f\u4e2d\u6587\u6ce8\u91ca
const message = "\u6b22\u8fce\u4f7f\u7528";
```

### 4. 文件创建规范

- ✅ 创建文件时明确使用 UTF-8 编码
- ✅ 文件末尾保留一个空行
- ✅ 删除行尾多余空格（Markdown 除外）

---

## 🔍 AI 自检清单

**创建或修改文件时，AI 必须检查**：

- [ ] 文件编码为 UTF-8？
- [ ] 无 BOM 标记？
- [ ] 换行符为 LF？（Windows 脚本除外）
- [ ] 中文内容无乱码？
- [ ] 文件末尾有空行？
- [ ] 无行尾多余空格？（Markdown 除外）

---

## 🚨 常见错误场景

### 场景1: 读取文件时遇到乱码

**错误做法**：
```
AI: "文件内容似乎有乱码，我猜测内容是..."
```

**正确做法**：
```
AI: "文件可能不是 UTF-8 编码，需要先确认编码格式"
AI: [使用工具检查文件编码]
AI: [转换为 UTF-8 后再处理]
```

### 场景2: 创建包含中文的文件

**错误做法**：
- 使用系统默认编码（可能是 GBK）
- 添加 BOM 标记
- 使用 Unicode 转义

**正确做法**：
- 明确指定 UTF-8 编码
- 不添加 BOM
- 直接使用中文字符

### 场景3: 跨平台文件

**错误做法**：
- 混用 CRLF 和 LF
- 不同文件使用不同换行符

**正确做法**：
- 统一使用 LF（除 Windows 脚本外）
- 配置 .gitattributes 强制规范

---

## 📋 编码验证方法

### PowerShell 验证命令

```powershell
# 检查文件编码
$bytes = [System.IO.File]::ReadAllBytes("file.html")
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "❌ 文件包含 BOM"
} else {
    Write-Host "✅ 文件无 BOM"
}

# 检查换行符
$content = Get-Content -Path "file.html" -Raw
if ($content -match '\r\n') {
    Write-Host "❌ 文件使用 CRLF"
} else {
    Write-Host "✅ 文件使用 LF"
}
```

### Node.js 验证方法

```javascript
const fs = require('fs');
const buffer = fs.readFileSync('file.html');

// 检查 BOM
if (buffer[0] === 0xEF && buffer[1] === 0xBB && buffer[2] === 0xBF) {
    console.log('❌ 文件包含 BOM');
} else {
    console.log('✅ 文件无 BOM');
}

// 检查换行符
const content = buffer.toString('utf8');
if (content.includes('\r\n')) {
    console.log('❌ 文件使用 CRLF');
} else {
    console.log('✅ 文件使用 LF');
}
```

---

## 🔧 编码问题修复

### 移除 BOM

```powershell
$content = Get-Content -Path "file.html" -Encoding UTF8
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines("file.html", $content, $utf8NoBom)
```

### 转换 CRLF 为 LF

```powershell
$content = Get-Content -Path "file.html" -Raw
$content = $content -replace "`r`n", "`n"
[System.IO.File]::WriteAllText("file.html", $content, [System.Text.Encoding]::UTF8)
```

### 转换文件编码

```powershell
# GBK 转 UTF-8
$content = Get-Content -Path "file.html" -Encoding Default
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines("file.html", $content, $utf8NoBom)
```

---

## 📚 相关文档

- `.github/ENCODING-PROTECTION.md` - 完整编码保护规范
- `.github/instructions/encoding-chinese.instructions.md` - 中文编码专项规则
- `.editorconfig` - 编辑器统一配置
- `.gitattributes` - Git 文件属性配置

---

> 🔴 **AI 必须记住**：**编码错误 = 工作白费，必须在创建文件时就确保编码正确！**
