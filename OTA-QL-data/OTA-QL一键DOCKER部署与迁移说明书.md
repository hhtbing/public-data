# 🐳 OTA-QL 一键 Docker 部署与迁移说明书

> **版本**: v3.0
> **适用项目**: OTA-QL — ESP32 雷达固件 OTA 升级管理服务
> **最后更新**: 2026-02-28

---

## 📋 目录

1. [概述](#1-概述)
2. [快速开始](#2-快速开始)
3. [部署脚本使用指南](#3-部署脚本使用指南)
4. [管理工具菜单](#4-管理工具菜单)
5. [版本管理与升级](#5-版本管理与升级)
6. [数据备份与恢复](#6-数据备份与恢复)
7. [服务器迁移](#7-服务器迁移)
8. [故障排查](#8-故障排查)
9. [公开仓库自动同步](#9-公开仓库自动同步)

---

## 1. 概述

### 1.1 系统简介

OTA-QL 是清澜雷达（ESP32-S3）固件 OTA 远程升级管理服务，支持：

- 🔌 **V2 协议** — TCP + Protobuf 长连接（端口 1060）
- 📡 **V3 协议** — HTTPS 认证 + MQTT 3.1.1（端口 443/1883）
- 🖥️ **Web 管理面板** — 设备管理、固件管理、OTA 推送、实时日志（端口 8690）
- 📦 **HTTP 固件服务** — Range 断点续传下载（端口 8688）

### 1.2 服务端口

| 服务 | 端口 | 协议 | 说明 |
|------|------|------|------|
| TCP 调度 | 1060 | TCP | V2 设备连接 |
| HTTP 固件 | 8688 | HTTP | 固件 Range 下载 |
| Web 管理 | 8690 | HTTP | 管理面板 + API |
| HTTPS 认证 | 443 | HTTPS | V3 设备认证 |
| MQTT | 1883 | MQTT | V3 消息通信 |

### 1.3 Docker 镜像

```
ghcr.io/hhtbing-wisefido/ota-ql:latest
```

---

## 2. 快速开始

### 2.1 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Ubuntu 20.04+ / Debian 11+ / CentOS 8+ |
| Docker | 20.10+ |
| 内存 | ≥ 512MB |
| 磁盘 | ≥ 1GB 可用空间 |
| 网络 | 需要开放 1060/8688/8690/443/1883 端口 |

### 2.2 一键部署（推荐）

```bash
wget -O ota-ql-docker-deploy.sh "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/ota-ql-docker-deploy.sh" && chmod +x ota-ql-docker-deploy.sh && sudo ./ota-ql-docker-deploy.sh
```

> 📌 部署脚本托管在公开仓库 [public-data/OTA-QL-data](https://github.com/hhtbing-wisefido/public-data/tree/main/OTA-QL-data)，由 GitHub Actions 从私有仓库自动同步。

### 2.3 部署流程概览

```
执行脚本 → 选择环境(生产/测试) → 自动拉取镜像 → 创建数据卷 → 启动容器 → 健康检查 → 显示密码
```

---

## 3. 部署脚本使用指南

### 3.1 首次部署

运行脚本后选择 `1. 部署/更新服务`，脚本会自动：

1. ✅ 检测 Docker 是否安装（未安装则自动安装）
2. ✅ 拉取最新镜像
3. ✅ 选择部署环境（生产 / 测试）
4. ✅ 创建数据卷目录
5. ✅ 启动容器（5端口映射）
6. ✅ 执行健康检查（API + TCP 双重检测）
7. ✅ 显示管理员初始密码

### 3.2 环境选择

| 环境 | 域名 | 用途 |
|------|------|------|
| 生产环境 | `*.wisefido.com` | 正式运营 |
| 测试环境 | `*.wisefido.work` | 开发调试 |

### 3.3 部署后首次访问

部署成功后，脚本会显示：

```
🔐 管理面板地址: http://<服务器IP>:8690
🔑 初始密码: <随机生成>
```

⚠️ **请务必记录初始密码！** 登录后可在"用户管理"中修改。

---

## 4. 管理工具菜单

运行 `sudo ./ota-ql-docker-deploy.sh` 进入交互式菜单：

```
====================================
  OTA-QL Docker 管理工具 v3.0
====================================
 1. 部署/更新服务
 2. 检查存储卷
 3. 查看容器状态
 4. 查看日志
 5. 健康检查
 6. 备份数据
 7. 恢复数据
 8. 查看备份
 9. 重置管理员密码
10. 删除服务
11. 退出
```

### 4.1 部署/更新服务（菜单 1）

- **首次部署**: 全新安装，自动生成初始密码
- **更新升级**: 备份当前镜像版本 → 拉取新镜像 → 重启容器 → 健康检查

### 4.2 检查存储卷（菜单 2）

5项检查：
- 📁 数据目录是否存在
- 🔗 容器挂载点是否正确
- 💾 Docker 卷状态
- 📊 磁盘空间使用率
- 📋 关键文件是否存在

### 4.3 查看日志（菜单 4）

支持多种过滤模式：
- 全部日志 / 最近50行 / 最近100行
- 🔄 OTA 记录专用过滤（grep OTA 相关关键词）
- 📡 设备连接专用过滤（grep 设备上线/离线）

### 4.4 健康检查（菜单 5）

双重检测机制：
- **API 检测**: `curl http://localhost:8690/api/health`
- **TCP 检测**: 检测 1060 端口是否可连接

### 4.5 备份数据（菜单 6）

备份内容：
- `/app/data/` — 用户数据、认证信息
- `/app/firmware/` — 已上传的固件文件
- `/app/certs/` — TLS 证书
- `/app/logs/` — 运行日志

备份文件保存在 `./backups/` 目录，格式：`ota-ql-backup-YYYYMMDD-HHMMSS.tar.gz`

### 4.6 恢复数据（菜单 7）

从备份文件恢复数据，恢复后自动重启容器。

### 4.7 查看备份（菜单 8）

子菜单功能：
- 📋 查看备份文件内容列表
- 🗑️ 删除指定备份
- 🧹 清理旧备份（保留最近3个）

### 4.8 重置管理员密码（菜单 9）

删除认证数据文件 → 重启容器 → 系统自动生成新的初始密码。

```bash
# 重置流程
停止容器 → 删除 admin.json → 启动容器 → 从日志获取新密码
```

### 4.9 删除服务（菜单 10）

两种模式：
- **仅删除容器和镜像**（保留数据卷）
- **完全清除**（包括数据卷，不可恢复）

---

## 5. 版本管理与升级

### 5.1 Docker 镜像标签

| 标签格式 | 示例 | 说明 |
|---------|------|------|
| `latest` | `latest` | 最新稳定版 |
| `v{major}.{minor}.{patch}` | `v0.3.0` | 完整语义化版本 |
| `{major}.{minor}` | `0.3` | 主.次版本 |
| `main-{sha}` | `main-aeb8c8a` | 提交哈希（调试用） |

### 5.2 升级流程

```bash
# 方式一：使用脚本（推荐）
sudo ./ota-ql-docker-deploy.sh
# 选择 1. 部署/更新服务

# 方式二：手动升级
docker pull ghcr.io/hhtbing-wisefido/ota-ql:latest
docker stop ota-ql
docker rm ota-ql
# 重新启动容器（使用原有参数）
```

### 5.3 版本回滚

使用指定版本标签回滚：

```bash
docker pull ghcr.io/hhtbing-wisefido/ota-ql:v0.2.0
docker stop ota-ql
docker rm ota-ql
# 使用 v0.2.0 标签重新启动
```

### 5.4 GitHub Release

每次发布新版本时：
1. 在 GitHub 创建 Release（tag 格式：`v0.3.0`）
2. CI/CD 自动构建 Docker 镜像
3. 镜像推送到 GHCR 并打上版本标签
4. 部署脚本自动同步到公开仓库 public-data

---

## 6. 数据备份与恢复

### 6.1 数据卷结构

```
/app/
├── data/          ← 用户数据、认证信息
│   └── admin.json ← 管理员账户（密码哈希）
├── firmware/      ← 上传的固件文件
├── certs/         ← TLS/SSL 证书
└── logs/          ← 运行日志
```

### 6.2 手动备份

```bash
# 创建备份
docker exec ota-ql tar -czf /tmp/backup.tar.gz /app/data /app/firmware /app/certs
docker cp ota-ql:/tmp/backup.tar.gz ./ota-ql-backup-$(date +%Y%m%d).tar.gz
```

### 6.3 自动备份建议

```bash
# 添加到 crontab，每天凌晨2点自动备份
0 2 * * * /path/to/ota-ql-docker-deploy.sh backup 2>&1 >> /var/log/ota-ql-backup.log
```

---

## 7. 服务器迁移

### 7.1 迁移步骤

#### 在旧服务器上

```bash
# 1. 备份数据
sudo ./ota-ql-docker-deploy.sh
# 选择 6. 备份数据

# 2. 将备份文件传输到新服务器
scp ./backups/ota-ql-backup-*.tar.gz user@新服务器:/tmp/
```

#### 在新服务器上

```bash
# 1. 下载部署脚本
wget -O ota-ql-docker-deploy.sh "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/ota-ql-docker-deploy.sh"
chmod +x ota-ql-docker-deploy.sh

# 2. 先部署服务
sudo ./ota-ql-docker-deploy.sh
# 选择 1. 部署/更新服务

# 3. 复制备份文件到 backups 目录
mkdir -p backups
cp /tmp/ota-ql-backup-*.tar.gz ./backups/

# 4. 恢复数据
sudo ./ota-ql-docker-deploy.sh
# 选择 7. 恢复数据
```

### 7.2 迁移注意事项

- ✅ 备份文件包含用户账户和密码，恢复后原密码仍可用
- ✅ 固件文件会一并恢复
- ⚠️ TLS 证书可能需要重新配置（如域名变更）
- ⚠️ 确保新服务器防火墙放行所有必需端口

---

## 8. 故障排查

### 8.1 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 容器无法启动 | 端口被占用 | `netstat -tlnp \| grep -E "1060\|8688\|8690\|443\|1883"` |
| 健康检查失败 | 服务未完全启动 | 等待30秒后重试 |
| 忘记初始密码 | 未记录 | 使用菜单 9 重置密码 |
| 设备无法连接 | 防火墙未放行 | 检查 iptables/ufw 规则 |
| 镜像拉取失败 | 网络问题 | 检查 Docker daemon 代理设置 |

### 8.2 日志查看

```bash
# 查看实时日志
docker logs -f ota-ql

# 查看最近100行
docker logs --tail 100 ota-ql

# 搜索 OTA 相关日志
docker logs ota-ql 2>&1 | grep -i "ota"

# 搜索设备连接日志
docker logs ota-ql 2>&1 | grep -i "device\|connect\|online"
```

### 8.3 容器状态检查

```bash
# 容器运行状态
docker ps -a --filter name=ota-ql

# 容器资源占用
docker stats ota-ql --no-stream

# API 健康检查
curl -s http://localhost:8690/api/health | python3 -m json.tool
```

### 8.4 数据卷检查

```bash
# 查看数据目录
docker exec ota-ql ls -la /app/data/
docker exec ota-ql ls -la /app/firmware/

# 检查磁盘空间
docker exec ota-ql df -h /app/
```

---

## 9. 公开仓库自动同步

### 9.1 同步机制

OTA-QL 仓库是 **私有仓库**，外部用户无法直接下载部署脚本。通过 GitHub Actions 自动同步到公开仓库 `public-data`，实现：

- ✅ 私有仓库代码安全
- ✅ 部署脚本公开可下载（raw URL 直接下载）
- ✅ 代码更新后自动同步

### 9.2 同步目标

| 项目 | 说明 |
|------|------|
| **公开仓库** | [hhtbing-wisefido/public-data](https://github.com/hhtbing-wisefido/public-data) |
| **目标目录** | `OTA-QL-data/` |
| **同步文件** | `ota-ql-docker-deploy.sh` + `OTA-QL一键DOCKER部署与迁移说明书.md` |
| **触发方式** | 推送到 main 分支时自动触发 / 手动触发 |

### 9.3 下载地址

```bash
# 部署脚本
wget -O ota-ql-docker-deploy.sh "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/ota-ql-docker-deploy.sh"

# 部署说明书
wget "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/OTA-QL一键DOCKER部署与迁移说明书.md"
```

### 9.4 设置步骤（仓库管理员）

1. 创建 PAT：GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → 勾选 `repo` 权限
2. 配置 Secret：OTA-QL 仓库 → Settings → Secrets → 添加 `PUBLIC_REPO_TOKEN`（值为 PAT）
3. 手动触发一次 workflow 验证同步成功

---

## 📚 附录

### A. Docker Compose 参考

如需使用 Docker Compose，创建 `docker-compose.yml`：

```yaml
version: '3.8'
services:
  ota-ql:
    image: ghcr.io/hhtbing-wisefido/ota-ql:latest
    container_name: ota-ql
    restart: unless-stopped
    ports:
      - "1060:1060"
      - "8688:8688"
      - "8690:8690"
      - "443:443"
      - "1883:1883"
    volumes:
      - ./ota-data/firmware:/app/firmware
      - ./ota-data/certs:/app/certs
      - ./ota-data/logs:/app/logs
      - ./ota-data/data:/app/data
    environment:
      - OTA_LOG_LEVEL=info
```

### B. 防火墙配置

```bash
# UFW（Ubuntu）
sudo ufw allow 1060/tcp
sudo ufw allow 8688/tcp
sudo ufw allow 8690/tcp
sudo ufw allow 443/tcp
sudo ufw allow 1883/tcp

# firewalld（CentOS）
sudo firewall-cmd --permanent --add-port=1060/tcp
sudo firewall-cmd --permanent --add-port=8688/tcp
sudo firewall-cmd --permanent --add-port=8690/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=1883/tcp
sudo firewall-cmd --reload
```

### C. 技术支持

- **项目仓库**: https://github.com/hhtbing-wisefido/OTA-QL（私有）
- **部署脚本下载**: https://github.com/hhtbing-wisefido/public-data/tree/main/OTA-QL-data

---

> ⚡ **版本历史**: v3.0 (2026-02-28) — 初始版本，基于 owl-website 部署文档模板
