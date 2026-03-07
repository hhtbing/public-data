# 🐳 OTA-QL 一键 Docker 部署与迁移说明书

> **版本**: v5.1
> **适用项目**: OTA-QL — ESP32 雷达固件 OTA 升级管理服务
> **最后更新**: 2026-03-08

---

## 📋 目录

1. [概述](#1-概述)
2. [快速开始](#2-快速开始)
3. [部署脚本使用指南](#3-部署脚本使用指南)
4. [管理工具菜单](#4-管理工具菜单)
5. [设备回调地址](#5-设备回调地址)
6. [SSL 证书管理](#6-ssl-证书管理v50-新增)
7. [版本管理与升级](#7-版本管理与升级)
8. [数据备份与恢复](#8-数据备份与恢复)
9. [服务器迁移](#9-服务器迁移)
10. [故障排查](#10-故障排查)
11. [公开仓库自动同步](#11-公开仓库自动同步)

---

## 1. 概述

### 1.1 系统简介

OTA-QL 是清澜雷达（ESP32-S3）固件 OTA 远程升级管理服务，支持：

- 🔌 **cmux 设备网关** — 端口 10086（TCP+TLS 自动识别，设备直连）
- 📡 **MQTT 3.1.1 Broker** — 端口 1883（明文）/ 8883（TLS）
- 🖥️ **HTTPS 统一服务** — Web 管理面板 + API（端口 10088）
- 📦 **HTTP 固件服务** — ESP32 OTA 明文固件下载（端口 10089）

### 1.2 服务端口

| 服务 | 端口 | 协议 | 说明 |
|------|------|------|------|
| HTTPS 统一 | 10088 | HTTPS | Web 管理 + API |
| HTTP 固件 | 10089 | HTTP | ESP32 OTA 明文固件下载 |
| cmux 网关 | 10086 | TCP/TLS | 设备连接（自动识别协议） |
| MQTT | 1883 | MQTT | 消息通信（明文） |
| MQTTS | 8883 | MQTTS | 消息通信（TLS 加密） |

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
| 网络 | 需要开放 10088/10089/10086/1883/8883 端口 |

### 2.2 一键部署（推荐）

```bash
wget -O ota-ql-docker-deploy.sh "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/ota-ql-docker-deploy.sh" && chmod +x ota-ql-docker-deploy.sh && sudo ./ota-ql-docker-deploy.sh
```

> 📌 部署脚本托管在公开仓库 [public-data/OTA-QL-data](https://github.com/hhtbing-wisefido/public-data/tree/main/OTA-QL-data)，由 GitHub Actions 从私有仓库自动同步。

### 2.3 部署流程概览

```
执行脚本 → 选择环境(生产/测试) → 设置设备回调地址 → 🆕自动搜索SSL证书 → 自动拉取镜像 → 创建数据卷 → 启动容器 → 健康检查 → 显示密码+回调地址
```

---

## 3. 部署脚本使用指南

### 3.1 首次部署

运行脚本后选择 `1. 一键部署(生产环境-安全)`，脚本会自动：

1. ✅ 检测 Docker 是否安装（未安装则自动安装）
2. ✅ 创建数据卷目录
3. ✅ **交互式设置设备回调地址**（域名或IP）
4. 🆕 **自动搜索宝塔/aaPanel/ACME等面板的SSL证书**（17种路径数据库）
5. ✅ 检查端口冲突
6. ✅ 拉取最新镜像
7. ✅ 启动容器（5端口映射 + 回调地址环境变量）
8. ✅ 执行健康检查（HTTPS API + 设备网关 双重检测）
9. ✅ 显示管理员初始密码 + 设备回调地址信息

### 3.2 环境选择

| 环境 | 域名 | 用途 |
|------|------|------|
| 生产环境 | `*.wisefido.com` | 正式运营 |
| 测试环境 | `*.wisefido.work` | 开发调试 |

### 3.3 部署后首次访问

部署成功后，脚本会显示：

```
🔐 管理面板地址: https://<服务器IP>:10088
🔑 初始密码: <随机生成>
```

⚠️ **请务必记录初始密码！** 登录后可在"用户管理"中修改。

---

## 4. 管理工具菜单

运行 `sudo ./ota-ql-docker-deploy.sh` 进入交互式菜单：

```
==========================================
  OTA-QL 管理工具 (v5.1)
==========================================

  1.  一键部署 (生产环境-安全)
  2.  检查存储卷
  3.  查看部署信息
  4.  重置管理员密码
  5.  检查更新
  6.  一键备份数据
  7.  一键恢复数据
  8.  备份管理
  9.  查看日志
  10. 设备回调地址设置与查看
  11. SSL证书管理 🆕
  12. 退出
  13. 一键部署 (仅测试-不安全)
```

### 4.1 部署/更新服务（菜单 1 / 12）

- **菜单 1 — 生产环境**: HTTPS管理绑定 127.0.0.1（Nginx反代），设备端口绑定 0.0.0.0
- **菜单 12 — 测试环境**: 全部端口绑定 0.0.0.0（⚠️ 不安全）
- 部署时会交互提示设置设备回调地址
- **首次部署**: 全新安装，自动生成初始密码
- **更新升级**: 备份当前镜像 → 拉取新镜像 → 重启容器 → 健康检查

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
- **HTTPS API 检测**: `curl -sk https://localhost:10088/api/health`
- **设备网关检测**: 检测 10086 端口是否可连接

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

### 4.8 重置管理员密码（菜单 4）

删除认证数据文件 → 重启容器 → 系统自动生成新的初始密码。

```bash
# 重置流程
停止容器 → 删除 admin.json → 启动容器 → 从日志获取新密码
```

### 4.9 设备回调地址设置与查看（菜单 10） 🆕

进入后包含两个子菜单：

| 子菜单 | 功能 |
|-------|------|
| **1. 设置/修改设备回调地址** | 交互式输入新地址，保存后可选重启容器使其生效 |
| **2. 查看当前设备回调地址** | 显示当前回调地址及派生的 MQTT/固件下载地址 |

```bash
# 子菜单1 设置流程
输入新地址 → 保存到 /opt/ota-ql/.callback_addr → 重启容器(可选)

# 子菜单2 查看显示
回调地址 + MQTT Broker 地址 + 固件下载地址 + 存储位置 + 环境变量
```

---

## 5. 设备回调地址

### 5.1 什么是设备回调地址？

设备通过网关(:10086)连接服务器认证后，服务器返回此地址告诉设备：
1. **MQTT Broker 地址**: `<回调地址>:8883`（MQTTS TLS）
2. **OTA 固件下载地址**: `http://<回调地址>:10089/firmware`

简单理解：**设备认证后"回拨"到这个地址获取 MQTT 和固件服务**。

### 5.2 与设备接入网关地址的区别

| 对比项 | 设备接入网关地址 | 设备回调地址 |
|-------|---------------|------------|
| 存储位置 | 设备 NVS（ESP32 闪存） | 服务器 `/opt/ota-ql/.callback_addr` |
| 配置方式 | 蓝牙配置（EspBlufi App） | 部署脚本交互输入 |
| 使用时机 | 设备上电，发起认证 | 认证后，服务器返回给设备 |
| 修改方式 | 逐台设备蓝牙配置 | 服务器一处修改，所有设备生效 |
| 涉及端口 | :10086 | :8883, :10089 |

### 5.3 设置方式

**方式一：部署时自动提示**

执行菜单 1（生产部署）或 12（测试部署）时，脚本会交互提示输入：

```
=========================================
  设备回调地址设置
=========================================

什么是设备回调地址？
  设备通过网关(:10086)连接服务器并认证后，
  服务器会返回此地址告诉设备：
    1. MQTT Broker 连接到哪里 (此地址:8883)
    2. OTA 固件从哪里下载 (http://此地址:10089/firmware)

地址格式：域名(推荐) 或 IP 均可
  域名示例: ota.wisefido.com
  IP示例:   166.1.190.154

请输入设备回调地址 (域名或IP): ota.wisefido.com
[SUCCESS] 设备回调地址已设置: ota.wisefido.com
```

**方式二：菜单 10 设置与查看**

选择菜单 10 进入子菜单：
- **子菜单 1**：设置/修改回调地址，输入新地址后提示是否重启容器（环境变量修改需要重启才能生效）
- **子菜单 2**：查看当前回调地址及派生的 MQTT Broker 地址、固件下载地址、存储位置等详细信息

### 5.4 部署总结中的显示

部署完成后，总结信息中会显示：

```
[设备回调地址]
  ✓ 回调地址:   ota.wisefido.com
  MQTT地址:    ota.wisefido.com:8883 (MQTTS/TLS)
  固件下载:    http://ota.wisefido.com:10089/firmware
```

### 5.5 域名 vs IP

| 填法 | 优势 | 劣势 |
|------|------|------|
| 域名（推荐） | 迁移服务器只需改 DNS | 依赖 DNS 解析 |
| IP | 无需 DNS | 换 IP 需重新部署 |

---

### 4.10 SSL 证书管理（菜单 11）🆕

进入后包含六个子菜单：

| 子菜单 | 功能 |
|-------|------|
| **1. 查看已部署证书** | 显示当前 `/opt/ota-ql/certs/` 中的证书有效期与域名 |
| **2. 自动搜索并部署证书** | 根据回调域名扫描 17 种面板路径，找到后一键部署 |
| **3. 全局搜索所有证书** | 列出服务器上所有已发现的 SSL 证书 |
| **4. 手动部署证书** | 手动输入证书路径，验证后复制到 OTA-QL 目录 |
| **5. 证书配置指南** | 显示各面板（宝塔/aaPanel/ACME）证书位置说明 |
| **6. 跨域名证书部署** | 搜索证书并分析 SAN 覆盖范围，单证书服务多域名（v5.1） |

---

## 6. SSL 证书管理（v5.0 新增）

### 6.1 证书架构说明

OTA-QL 服务有三个对外地址，分别使用**不同来源**的 SSL 证书：

| 访问地址 | 端口 | 证书管理方 | 证书类型 | 说明 |
|---------|------|----------|---------|------|
| `https://domain:10088` | 10088 | Nginx（宝塔） | Let's Encrypt | Web 管理面板、浏览器访问 |
| `tls://domain:10086` | 10086 | **OTA-QL Go 服务器** | **需 CA 签发** | ESP32 设备直连认证网关 |
| `mqtts://domain:8883` | 8883 | **OTA-QL Go 服务器** | **需 CA 签发** | ESP32 MQTT TLS 通信 |

> ⚠️ **为什么 ESP32 需要 CA 签发证书？**
>
> ESP32 使用 `esp-x509-crt-bundle`（Mozilla CA 根证书包）验证服务器，**自签名证书会被拒绝**。10086 / 8883 端口由 Go 服务器直接处理 TLS，Nginx 不参与，因此必须为 Go 服务器配置 Let's Encrypt 等 CA 签发的证书。

### 6.2 证书路径数据库（17 种）

脚本 v5.0 内置 17 种面板的证书搜索路径：

| 编号 | 来源 | fullchain 路径 | privkey 路径 |
|------|------|--------------|------------|
| 1 | 宝塔(BaoTa) cert/ | `/www/server/panel/vhost/cert/<域名>/fullchain.pem` | `privkey.pem` |
| 2 | 宝塔(BaoTa) ssl/ | `/www/server/panel/vhost/ssl/<域名>/fullchain.pem` | `privkey.pem` |
| 3 | aaPanel cert/ | `/www/server/panel/vhost/cert/<域名>/fullchain.pem` | `privkey.pem` |
| 4 | aaPanel ssl/ | `/www/server/panel/vhost/ssl/<域名>/fullchain.pem` | `privkey.pem` |
| 5 | Certbot | `/etc/letsencrypt/live/<域名>/fullchain.pem` | `privkey.pem` |
| 6 | Certbot（域名变体） | `/etc/letsencrypt/live/<域名>-{0001..0005}/fullchain.pem` | `privkey.pem` |
| 7 | ACME.sh（~/.acme.sh） | `~/.acme.sh/<域名>/fullchain.cer` | `<域名>.key` |
| 8 | ACME.sh（~/.acme.sh ECC） | `~/.acme.sh/<域名>_ecc/fullchain.cer` | `<域名>.key` |
| 9 | ACME.sh（/root/.acme.sh） | `/root/.acme.sh/<域名>/fullchain.cer` | `<域名>.key` |
| 10 | ACME.sh（/usr/local/.acme.sh） | `/usr/local/.acme.sh/<域名>/fullchain.cer` | `<域名>.key` |
| 11 | Nginx（宝塔 conf） | `/www/server/panel/vhost/cert/<域名>/fullchain.pem` | `privkey.pem` |
| 12 | 1Panel | `/opt/1panel/data/apps/openresty/openresty/conf/cert/<域名>/fullchain.pem` | `privkey.pem` |
| 13 | Caddy | `/etc/caddy/cert/<域名>/fullchain.pem` | `privkey.pem` |
| 14 | 系统路径 /etc/ssl | `/etc/ssl/certs/<域名>/fullchain.pem` | `/etc/ssl/private/<域名>/privkey.pem` |
| 15 | Nginx vhost | `/etc/nginx/ssl/<域名>/fullchain.pem` | `privkey.pem` |
| 16 | Apache vhost | `/etc/apache2/ssl/<域名>/fullchain.pem` | `privkey.pem` |
| 17 | DirectAdmin | `/usr/local/directadmin/data/users/admin/domains/<域名>/fullchain.pem` | `privkey.pem` |

### 6.3 搜索结果解读（常见问题：为何显示 3 个证书？）

以域名 `ota.wisefido.work` 为例，脚本可能显示：

```
[1] 宝塔面板(BaoTa) - cert目录
    fullchain: /www/server/panel/vhost/cert/ota.wisefido.work/fullchain.pem ✓
    privkey:   /www/server/panel/vhost/cert/ota.wisefido.work/privkey.pem   ✓

[2] 宝塔面板(BaoTa) - ssl目录
    fullchain: /www/server/panel/vhost/ssl/ota.wisefido.work/fullchain.pem  ✓
    privkey:   /www/server/panel/vhost/ssl/ota.wisefido.work/privkey.pem    ✓

[3] aaPanel - cert目录
    fullchain: /www/server/panel/vhost/cert/ota.wisefido.work/fullchain.pem ✓
    privkey:   /www/server/panel/vhost/cert/ota.wisefido.work/privkey.pem   ✓
```

**原因分析：**

| 编号 | 实质 | 说明 |
|-----|------|------|
| **[1] 宝塔 cert/** | ✅ 真实文件 | 宝塔 Let's Encrypt 证书的实际存放位置 |
| **[2] 宝塔 ssl/** | ⚠️ 通常是软链接 | `ssl/` 目录通常 symlink 到 `cert/`，指向同一个证书 |
| **[3] aaPanel cert/** | ⚠️ 误报 | 宝塔与 aaPanel 共用相同路径模板，实际不是 aaPanel 安装 |

> ✅ **推荐选择 [1] 宝塔面板(BaoTa) cert/ 目录** — 这是真实文件，最稳定可靠。

### 6.4 自动搜索与部署流程

```
一键部署(菜单1) 或 SSL证书管理(菜单11→子菜单2)
        ↓
从回调地址中提取域名
（如 ota.wisefido.work）
        ↓
遍历17种路径数据库
        ↓
   ┌────┴────┐
找到1个      找到多个（如3个）
   ↓           ↓
自动部署    列表显示，提示选择编号
              ↓
         输入编号（推荐选[1]）
              ↓
         验证 PEM 格式是否合法
              ↓
         cp 到 /opt/ota-ql/certs/
              ↓
         重启容器（证书挂载生效）
```

### 6.5 宝塔用户快速参考

```bash
# 确认宝塔证书位置
ls /www/server/panel/vhost/cert/ota.wisefido.work/
# 应显示: fullchain.pem  privkey.pem

# 手动部署（如自动搜索失败）
sudo mkdir -p /opt/ota-ql/certs
sudo cp /www/server/panel/vhost/cert/ota.wisefido.work/fullchain.pem /opt/ota-ql/certs/
sudo cp /www/server/panel/vhost/cert/ota.wisefido.work/privkey.pem   /opt/ota-ql/certs/

# 重启容器使证书生效
docker restart ota-ql
```

### 6.6 证书续期后同步

Let's Encrypt 证书每 90 天自动续期，续期后需同步到 OTA-QL：

**方式一：脚本菜单（推荐）**
```bash
sudo ./ota-ql-docker-deploy.sh
# 选择 11. SSL证书管理 → 2. 自动搜索并部署证书
```

**方式二：手动复制**
```bash
sudo cp /www/server/panel/vhost/cert/ota.wisefido.work/fullchain.pem /opt/ota-ql/certs/
sudo cp /www/server/panel/vhost/cert/ota.wisefido.work/privkey.pem   /opt/ota-ql/certs/
docker restart ota-ql
```

**方式三：宝塔定时任务**

在宝塔面板 → 计划任务 → 新建，每月1日执行：
```bash
cp /www/server/panel/vhost/cert/ota.wisefido.work/fullchain.pem /opt/ota-ql/certs/ && \
cp /www/server/panel/vhost/cert/ota.wisefido.work/privkey.pem   /opt/ota-ql/certs/ && \
docker restart ota-ql
```

---

## 7. 版本管理与升级

### 6.1 Docker 镜像标签

| 标签格式 | 示例 | 说明 |
|---------|------|------|
| `latest` | `latest` | 最新稳定版 |
| `v{major}.{minor}.{patch}` | `v0.3.0` | 完整语义化版本 |
| `{major}.{minor}` | `0.3` | 主.次版本 |
| `main-{sha}` | `main-aeb8c8a` | 提交哈希（调试用） |

### 6.2 升级流程

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

### 6.3 版本回滚

使用指定版本标签回滚：

```bash
docker pull ghcr.io/hhtbing-wisefido/ota-ql:v0.2.0
docker stop ota-ql
docker rm ota-ql
# 使用 v0.2.0 标签重新启动
```

### 6.4 GitHub Release

每次发布新版本时：
1. 在 GitHub 创建 Release（tag 格式：`v0.3.0`）
2. CI/CD 自动构建 Docker 镜像
3. 镜像推送到 GHCR 并打上版本标签
4. 部署脚本自动同步到公开仓库 public-data

---

## 8. 数据备份与恢复

### 8.1 数据卷结构

```
/app/
├── data/          ← 用户数据、认证信息
│   └── admin.json ← 管理员账户（密码哈希）
├── firmware/      ← 上传的固件文件
├── certs/         ← TLS/SSL 证书
└── logs/          ← 运行日志
```

### 8.2 手动备份

```bash
# 创建备份
docker exec ota-ql tar -czf /tmp/backup.tar.gz /app/data /app/firmware /app/certs
docker cp ota-ql:/tmp/backup.tar.gz ./ota-ql-backup-$(date +%Y%m%d).tar.gz
```

### 8.3 自动备份建议

```bash
# 添加到 crontab，每天凌晨2点自动备份
0 2 * * * /path/to/ota-ql-docker-deploy.sh backup 2>&1 >> /var/log/ota-ql-backup.log
```

---

## 9. 服务器迁移

### 9.1 迁移步骤

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

### 9.2 迁移注意事项

- ✅ 备份文件包含用户账户和密码，恢复后原密码仍可用
- ✅ 固件文件会一并恢复
- ⚠️ TLS 证书可能需要重新配置（如域名变更）
- ⚠️ 确保新服务器防火墙放行所有必需端口

---

## 10. 故障排查

### 10.1 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 容器无法启动 | 端口被占用 | `netstat -tlnp \| grep -E "10088\|10089\|10086\|1883\|8883"` |
| 健康检查失败 | 服务未完全启动 | 等待30秒后重试 |
| 忘记初始密码 | 未记录 | 使用菜单 4 重置密码 |
| 设备无法连接 | 防火墙未放行 | 检查 iptables/ufw 规则 |
| 镜像拉取失败 | 网络问题 | 检查 Docker daemon 代理设置 |

### 10.2 日志查看

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

### 10.3 容器状态检查

```bash
# 容器运行状态
docker ps -a --filter name=ota-ql

# 容器资源占用
docker stats ota-ql --no-stream

# API 健康检查
curl -sk https://localhost:10088/api/health | python3 -m json.tool
```

### 10.4 数据卷检查

```bash
# 查看数据目录
docker exec ota-ql ls -la /app/data/
docker exec ota-ql ls -la /app/firmware/

# 检查磁盘空间
docker exec ota-ql df -h /app/
```

---

## 11. 公开仓库自动同步

### 11.1 同步机制

OTA-QL 仓库是 **私有仓库**，外部用户无法直接下载部署脚本。通过 GitHub Actions 自动同步到公开仓库 `public-data`，实现：

- ✅ 私有仓库代码安全
- ✅ 部署脚本公开可下载（raw URL 直接下载）
- ✅ 代码更新后自动同步

### 11.2 同步目标

| 项目 | 说明 |
|------|------|
| **公开仓库** | [hhtbing-wisefido/public-data](https://github.com/hhtbing-wisefido/public-data) |
| **目标目录** | `OTA-QL-data/` |
| **同步文件** | `ota-ql-docker-deploy.sh` + `OTA-QL一键DOCKER部署与迁移说明书.md` |
| **触发方式** | 推送到 main 分支时自动触发 / 手动触发 |

### 11.3 下载地址

```bash
# 部署脚本
wget -O ota-ql-docker-deploy.sh "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/ota-ql-docker-deploy.sh"

# 部署说明书
wget "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/OTA-QL一键DOCKER部署与迁移说明书.md"
```

### 11.4 设置步骤（仓库管理员）

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
      - "10088:10088"
      - "10086:10086"
      - "1883:1883"
      - "8883:8883"
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
sudo ufw allow 10088/tcp
sudo ufw allow 10086/tcp
sudo ufw allow 1883/tcp
sudo ufw allow 8883/tcp

# firewalld（CentOS）
sudo firewall-cmd --permanent --add-port=10088/tcp
sudo firewall-cmd --permanent --add-port=10086/tcp
sudo firewall-cmd --permanent --add-port=1883/tcp
sudo firewall-cmd --permanent --add-port=8883/tcp
sudo firewall-cmd --reload
```

### C. 技术支持

- **项目仓库**: https://github.com/hhtbing-wisefido/OTA-QL（私有）
- **部署脚本下载**: https://github.com/hhtbing-wisefido/public-data/tree/main/OTA-QL-data

---

> ⚡ **版本历史**:  
> **v5.1** (2026-03-08) — 修复证书搜索重复误报BUG（realpath去重），新增跨域名证书部署（菜单11→子菜单6）  
> **v5.0** (2026-03-08) — 新增 SSL 证书管理（章节6 + 菜单11），内置17种面板路径数据库，部署时自动搜索并部署证书  
> **v4.6** (2026-03-08) — 菜单10增加子菜单（设置与查看），支持查看回调地址详情及派生服务地址