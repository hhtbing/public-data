# 🚀 通用Linux自动化工具集

## 📋 工具简介

这是一个功能强大的通用Linux自动化工具集，适用于各种Linux系统和面板，提供了丰富的系统管理功能。

## 📌 版本信息

- **当前版本**: v2.0
- **更新日期**: 2026-03-20
- **版本历史**:
  - v2.0: 增加版本化管理、抓包管理功能
  - v1.0: 初始版本，包含系统信息、SSL管理、网络工具、系统工具、文件管理

## ✨ 核心功能

- **🖥️ 系统信息查询**: 查看系统基本信息、CPU、内存、磁盘、网络等详细数据
- **🔒 SSL证书管理**: 支持多种面板和发行版的证书搜索、部署和管理
- **📡 网络工具**: 网络连接状态、端口占用、Ping测试、路由表查看
- **🛠️ 系统工具**: 系统资源监控、进程管理、磁盘空间分析、系统日志查看
- **📁 文件管理**: 文件搜索、文本内容搜索、文件权限管理、文件大小统计
- **🕵️ 抓包管理**: 支持tcpdump/tshark抓包，网口选择、关键词过滤、包分析、导入导出等功能

## 📦 支持的Linux面板

- 宝塔面板(BaoTa)
- 1Panel
- aaPanel
- CyberPanel
- AppNode
- cPanel
- Plesk
- 以及各种标准的Nginx/Apache/Caddy配置

## 🚀 一键部署

### 方法1: 直接下载运行
```bash
wget -O linux-tools.sh "https://raw.githubusercontent.com/hhtbing/public-data/main/linux-tools/linux-tools.sh" && chmod +x linux-tools.sh && sudo ./linux-tools.sh
```

### 方法2: 克隆仓库后运行
```bash
git clone https://github.com/hhtbing/public-data.git
cd public-data/linux-tools
chmod +x linux-tools.sh
sudo ./linux-tools.sh
```

## 📖 使用说明

### 1. 启动工具
```bash
sudo ./linux-tools.sh
```

### 2. 主菜单选项
```
==========================================
  🚀 通用Linux自动化工具集 (v2.0)
==========================================

  1. 🖥️  查询系统信息
  2. 🔒 SSL证书管理
  3. 📡 网络工具
  4. 🛠️  系统工具
  5. 📁 文件管理
  6. 🕵️  抓包管理
  0. 🚪 退出
```

### 3. SSL证书管理

SSL证书管理模块支持：
- 查看当前证书状态
- 按域名搜索并部署证书
- 全局搜索系统中所有证书
- 手动指定证书路径
- SSL证书申请指南

### 3. 命令行参数

工具支持以下命令行参数：

```bash
# 显示版本信息
sudo ./linux-tools.sh --version
# 或
sudo ./linux-tools.sh -v

# 显示帮助信息
sudo ./linux-tools.sh --help
# 或
sudo ./linux-tools.sh -h
```

### 4. SSL证书管理

SSL证书管理模块支持：
- 查看当前证书状态
- 按域名搜索并部署证书
- 全局搜索系统中所有证书
- 手动指定证书路径
- SSL证书申请指南

### 5. 系统信息查询

系统信息查询模块提供：
- 基本系统信息（系统版本、内核、架构等）
- CPU详细信息和使用率
- 内存使用情况
- 磁盘空间分析
- 网络配置和公网IP
- 系统负载情况

### 6. 抓包管理

抓包管理模块支持：
- **开始抓包**: 选择网口、抓包工具、过滤条件、保存文件名
- **分析已保存的包**: 查看包统计信息、内容、按协议过滤、关键词搜索
- **导入包文件**: 支持导入.pcap和.pcapng格式的包文件
- **导出包文件**: 将包文件导出到指定路径
- **抓包工具设置**: 查看已安装工具，获取安装命令

#### 支持的抓包工具
- tcpdump: 轻量级命令行抓包工具
- tshark: Wireshark的命令行版本，功能更强大

#### 抓包示例
1. 选择网口（如eth0、ens33等）
2. 选择抓包工具（tcpdump或tshark）
3. 设置过滤条件（如"tcp port 80"、"udp port 53"等）
4. 设置抓包数量（可选）
5. 设置保存文件名（默认使用时间戳命名）

## 🛠️ 工具依赖

工具会自动检测并使用系统中已安装的以下命令：
- openssl: 用于SSL证书管理
- ss/netstat: 用于网络工具
- top/ps: 用于系统工具
- df/du: 用于磁盘分析
- find/grep: 用于文件管理
- curl: 用于获取公网IP
- tcpdump/tshark: 用于抓包管理

### 抓包工具安装

```bash
# Debian/Ubuntu
sudo apt install tcpdump tshark -y

# CentOS/RHEL
sudo yum install tcpdump wireshark-cli -y

# Arch Linux
sudo pacman -S tcpdump wireshark-cli -y
```

## 🔧 自定义配置

可以通过修改脚本顶部的配置变量来自定义工具行为：

```bash
# 证书存储目录
CERTS_DIR="/opt/certs"

# 日志目录
LOG_DIR="/var/log/linux-tools"
```

## 📝 版本信息

- **版本**: v1.0
- **更新日期**: 2024-01-01
- **作者**: WiseFido Technologies

## 🤝 贡献

欢迎提交Issue和Pull Request来帮助改进这个工具！

## 📄 许可证

本工具采用MIT许可证开源。

## 📞 支持

如果您在使用过程中遇到问题，请：
1. 查看工具中的帮助信息
2. 检查系统日志
3. 提交Issue到GitHub仓库

---

**祝您使用愉快！** 🎉
