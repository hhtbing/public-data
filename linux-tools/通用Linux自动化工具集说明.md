# 通用Linux自动化工具集

## 工具简介

此工具为纯脚本自动化工具，适用于各种 Linux 发行版与主流面板，提供系统查询、证书管理、网络检查、系统分析和文件管理。

## 版本信息

- 当前版本: v2.1
- 更新日期: 2026-03-20
- 版本历史:
  - v2.1: 修复菜单语法、去除 emoji、增强端口占用进程信息和高级进程杀掉交互、自动证书路径搜索
  - v2.0: 增加版本化管理、抓包管理功能
  - v1.0: 初始版本

## 核心功能

- 系统信息查询
- SSL 证书管理（自动搜索面板/系统路径）
- 网络工具（端口占用 PID 查询、杀进程双重确认）
- 系统工具（资源、进程、日志）
- 文件管理（搜索、权限、统计）

## 使用方法

1. 下载脚本:

```bash
wget -O linux-tools.sh "https://raw.githubusercontent.com/hhtbing/public-data/main/linux-tools/linux-tools.sh"
chmod +x linux-tools.sh
```

2. 运行:

```bash
sudo ./linux-tools.sh
```

3. 或者:

```bash
./linux-tools.sh --sudo
```

## 命令行参数

- --help, -h
- --version, -v
- --sudo, -s

## 重要说明

- 端口占用查询支持 ss/netstat，可查看 PID 和命令行，并提供二次确认+倒计时杀进程。
- 证书状态不依赖硬编码 /opt/certs，自动搜索常见面板路径。
- 已去除脚本与菜单中的 emoji 图标，兼容所有终端。

## Git 同步(排除 AI 提示词)

使用 ALL_PROXY="socks5://127.0.0.1:4000" 后执行:

```bash
git add linux-tools.sh 通用Linux自动化工具集说明.md
git commit -m "update linux tools script and docs"
git push
```
