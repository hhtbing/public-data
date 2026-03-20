#requires -Version 5.1

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

# 始终以“仓库根目录”为基准执行检查，避免因当前工作目录不同而误报失败。
# 约定：此脚本位于 <repoRoot>\.github\run-v3-tests.ps1
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

function Test-BomPresent([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

function Test-BomAbsent([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    return -not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

function Should-ScanPath([string]$fullName) {
    # 仅对“项目自有内容”做编码保护扫描，排除第三方/缓存目录
    if ($fullName -match '\\.git\\') { return $false }
    if ($fullName -match '\\.venv\\') { return $false }
    if ($fullName -match '\\node_modules\\') { return $false }
    if ($fullName -match '\\知识库\\') { return $false }
    if ($fullName -match '\\\.pytest_cache\\') { return $false }
    return $true
}

$tests = New-Object System.Collections.Generic.List[object]

function Add-Test([string]$name, [scriptblock]$fn) {
    $tests.Add([pscustomobject]@{ Name = $name; Fn = $fn }) | Out-Null
}

Add-Test 'Test1 PS5 profile exists + BOM' {
    $p = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
    (Test-Path $p) -and (Test-BomPresent $p)
}

Add-Test 'Test2 PowerShell 7 exists' {
    Test-Path 'C:\Program Files\PowerShell\7\pwsh.exe'
}

Add-Test 'Test3 PS7 profile exists + BOM' {
    $p = Join-Path $env:USERPROFILE 'Documents\PowerShell\profile.ps1'
    (Test-Path $p) -and (Test-BomPresent $p)
}

Add-Test 'Test4 VS Code settings.json exists' {
    Test-Path (Join-Path $env:APPDATA 'Code\User\settings.json')
}

Add-Test 'Test5 .editorconfig exists' {
    Test-Path (Join-Path $RepoRoot '.editorconfig')
}

Add-Test 'Test6 .gitattributes exists' {
    Test-Path (Join-Path $RepoRoot '.gitattributes')
}

Add-Test 'Test7 Git pre-commit hook exists' {
    Test-Path (Join-Path $RepoRoot '.git\hooks\pre-commit')
}

Add-Test 'Test8 GitHub Actions workflow exists' {
    Test-Path (Join-Path $RepoRoot '.github\workflows\encoding-check.yml')
}

Add-Test 'Test9 AI encoding instruction exists' {
    Test-Path (Join-Path $RepoRoot '.github\instructions\encoding-check.instructions.md')
}

Add-Test 'Test10 Text files (html/css/js/json/md/py) have NO BOM' {
    $patterns = @('*.html','*.css','*.js','*.json','*.md','*.py')
    $files = Get-ChildItem -Path $RepoRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            (Should-ScanPath $_.FullName)
        } |
        Where-Object {
            foreach ($pat in $patterns) {
                if ($_.Name -like $pat) { return $true }
            }
            return $false
        }

    foreach ($f in $files) {
        if (-not (Test-BomAbsent $f.FullName)) { return $false }
    }
    return $true
}

Add-Test 'Test11 All .ps1 files have BOM' {
    $files = Get-ChildItem -Path $RepoRoot -Recurse -File -Force -Filter '*.ps1' -ErrorAction SilentlyContinue |
        Where-Object { (Should-ScanPath $_.FullName) }
    foreach ($f in $files) {
        if (-not (Test-BomPresent $f.FullName)) { return $false }
    }
    return $true
}

Add-Test 'Test12 Chinese display' {
    $s = '测试中文: ✅ 编码保护系统'
    Write-Host $s
    return ($s -like '*测试中文*')
}

$passed = 0
$failed = 0
Write-Host '✅ 编码保护 v3.0 快速检查 (12项)' -ForegroundColor Cyan
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

foreach ($t in $tests) {
    $ok = $false
    try { $ok = & $t.Fn } catch { $ok = $false }
    if ($ok) {
        $passed++
        Write-Host ("  ✅ {0}" -f $t.Name) -ForegroundColor Green
    } else {
        $failed++
        Write-Host ("  ❌ {0}" -f $t.Name) -ForegroundColor Red
    }
}

Write-Host ''
Write-Host ("测试通过：{0}/12" -f $passed) -ForegroundColor Yellow

if ($failed -eq 0) {
    Write-Host '保护等级：🟢🟢🟢🟢🟢🟢 (6/6)' -ForegroundColor Green
    exit 0
}

Write-Host '保护等级：❌ 未达标（必须6/6）' -ForegroundColor Red
exit 1
