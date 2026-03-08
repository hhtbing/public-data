# 🐳 OTA-QL 一键 Docker 部署与迁移说明书

> **版本**: v8.9
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
12. [服务器部署及反代设置（v8.9 新增）](#12-服务器部署及反代设置v89-新增)

---

## 1. 概述

### 1.1 系统简介

OTA-QL 是清澜雷达（ESP32-S3）固件 OTA 远程升级管理服务，支持：

- 🔌 **cmux 设备网关** — 端口 10086（TCP+TLS 自动识别，设备直连）
- 📡 **MQTT 3.1.1 Broker** — 端口 1883（明文）/ 8883（TLS）
- 🖥️ **HTTPS 统一服务** — Web 管理面板 + API（端口 10088）
- 📦 **HTTP 固件服务** — ESP32 OTA 明文固件下载（端口 10089）

### 1.2 服务端口

| 服务 | 端口 | 协议 | 绑定 | 说明 |
|------|------|------|------|------|
| HTTPS 统一 | 10088 | HTTPS | 127.0.0.1 | Web 管理 + API（Nginx反代） |
| HTTP 固件 | 10089 | HTTP | 127.0.0.1 | ESP32 OTA 固件下载（v8.9: Nginx /firmware 反代） |
| cmux 网关 | 10086 | TCP/TLS | 0.0.0.0 | 设备连接（自动识别协议） |
| MQTT | 1883 | MQTT | 0.0.0.0 | 消息通信（明文） |
| MQTTS | 8883 | MQTTS | 0.0.0.0 | 消息通信（TLS 加密） |

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
| 网络 | 需要开放 443/10086/1883/8883 端口（10088/10089 仅本地） |

### 2.2 一键部署（推荐）

```bash
wget -O ota-ql-docker-deploy.sh "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/ota-ql-docker-deploy.sh" && chmod +x ota-ql-docker-deploy.sh && sudo ./ota-ql-docker-deploy.sh
```

> 📌 部署脚本托管在公开仓库 [public-data/OTA-QL-data](https://github.com/hhtbing-wisefido/public-data/tree/main/OTA-QL-data)，由 GitHub Actions 从私有仓库自动同步。

### 2.3 部署流程概览

```
执行脚本 → 选择环境(生产/测试) → 设置设备回调地址 → 🆕设置固件下载域名 → 🆕SSL证书配置(交互式+覆盖检查) → 自动拉取镜像 → 创建数据卷 → 启动容器 → 健康检查 → 显示密码+回调地址+固件域名
```

---

## 3. 部署脚本使用指南

### 3.1 首次部署

运行脚本后选择 `1. 一键部署(生产环境-安全)`，脚本会自动：

1. ✅ 检测 Docker 是否安装（未安装则自动安装）
2. ✅ 创建数据卷目录
3. ✅ **交互式设置设备回调地址**（域名或IP）
4. 🆕 **交互式设置固件下载域名**（OTA_FIRMWARE_URL_BASE，v8.9）
5. 🆕 **SSL证书配置**（交互式菜单：搜索已有/通配符/SAN多域名/覆盖检查/交互式申请）
6. ✅ 检查端口冲突
7. ✅ 拉取最新镜像
8. ✅ 启动容器（5端口映射 + 回调地址 + 固件域名环境变量）
9. ✅ 执行健康检查（HTTPS API + 设备网关 双重检测）
10. ✅ 显示管理员初始密码 + 设备回调地址 + 固件域名信息

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
  OTA-QL 管理工具 (v8.9)
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
  14. 固件下载域名设置与查看 🆕
  12. 退出
  13. 一键部署 (仅测试-不安全)
```

### 4.1 部署/更新服务（菜单 1 / 12）

- **菜单 1 — 生产环境**: HTTPS管理+固件绑定 127.0.0.1（Nginx反代），设备端口绑定 0.0.0.0
- **菜单 13 — 测试环境**: 全部端口绑定 0.0.0.0（⚠️ 不安全）
- 部署时会交互提示设置设备回调地址和固件下载域名
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
2. **OTA 固件下载地址**: `https://<固件域名>/firmware`（v8.9: 通过Nginx反代）

简单理解：**设备认证后"回拨"到这个地址获取 MQTT 和固件服务**。

### 5.2 与设备接入网关地址的区别

| 对比项 | 设备接入网关地址 | 设备回调地址 |
|-------|---------------|------------|
| 存储位置 | 设备 NVS（ESP32 闪存） | 服务器 `/opt/ota-ql/.callback_addr` |
| 配置方式 | 蓝牙配置（EspBlufi App） | 部署脚本交互输入 |
| 使用时机 | 设备上电，发起认证 | 认证后，服务器返回给设备 |
| 修改方式 | 逐台设备蓝牙配置 | 服务器一处修改，所有设备生效 |
| 涉及端口 | :10086 | :8883, :443/firmware |

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

[固件下载域名]
  ✓ 固件域名:   ota.wisefido.com
  ✓ 固件URL:    https://ota.wisefido.com/firmware
```

### 5.5 域名 vs IP

| 填法 | 优势 | 劣势 |
|------|------|------|
| 域名（推荐） | 迁移服务器只需改 DNS | 依赖 DNS 解析 |
| IP | 无需 DNS | 换 IP 需重新部署 |

---

### 4.10 SSL 证书管理（菜单 11）🆕

进入后包含九个子菜单：

| 子菜单 | 功能 |
|-------|------|
| **1. 查看已部署证书** | 显示当前 `/opt/ota-ql/certs/` 中的证书有效期与域名 |
| **2. 自动搜索并部署证书** | 根据回调域名扫描 17 种面板路径，找到后一键部署 |
| **3. 全局搜索所有证书** | 列出服务器上所有已发现的 SSL 证书 |
| **4. 手动部署证书** | 手动输入证书路径，验证后复制到 OTA-QL 目录 |
| **5. 证书配置指南** | 显示各面板（宝塔/aaPanel/ACME）证书位置说明 |
| **6. 跨域名证书部署** | 搜索证书并分析 SAN 覆盖范围，单证书服务多域名（v5.1） |
| **7. 查询证书覆盖情况** | 检查证书SAN是否覆盖回调地址/网关/Web面板（v5.3） |
| **8. 交互式申请 SAN 证书** | 引导式填写多域名+选择验证方式，一键申请并部署（v5.3） |
| **9. 交互式申请通配符证书** | 引导式填写基础域名+DNS验证指引，一键申请并部署（v5.3） |

### 4.11 固件下载域名设置与查看（菜单 14）🆕 v8.9

进入后包含两个子菜单：

| 子菜单 | 功能 |
|-------|------|
| **1. 设置/修改固件下载域名** | 交互式输入域名，保存后可选重启容器使 `OTA_FIRMWARE_URL_BASE` 生效 |
| **2. 查看当前固件下载域名** | 显示当前固件域名、固件URL、Nginx配置说明 |

```bash
# 子菜单1 设置流程
输入域名 → 保存到 /opt/ota-ql/.firmware_domain → 重启容器(可选)
# 容器重启后 OTA_FIRMWARE_URL_BASE=https://<域名>/firmware 生效

# 子菜单2 查看显示
固件域名 + 固件URL + 环境变量 + Nginx反代配置表
```

> ⚠️ **前置条件**：使用此功能前，必须先在 Nginx 中配置 `/firmware` 反向代理到 `http://127.0.0.1:10089`（详见[第12章](#12-服务器部署及反代设置v89-新增)）。

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
      - "127.0.0.1:10088:10088"   # Web管理 (Nginx反代)
      - "127.0.0.1:10089:10089"   # 固件下载 (Nginx /firmware 反代)
      - "0.0.0.0:10086:10086"     # 设备网关 (直连)
      - "0.0.0.0:1883:1883"       # MQTT (直连)
      - "0.0.0.0:8883:8883"       # MQTTS (直连)
    volumes:
      - ./ota-data/firmware:/app/firmware
      - ./ota-data/certs:/app/certs
      - ./ota-data/logs:/app/logs
      - ./ota-data/data:/app/data
    environment:
      - OTA_LOG_LEVEL=info
      - OTA_SERVER_ADDR=ota.wisefido.com
      - OTA_FIRMWARE_URL_BASE=https://ota.wisefido.com/firmware
```

### B. 防火墙配置

```bash
# UFW（Ubuntu）
sudo ufw allow 443/tcp     # Nginx HTTPS (Web管理+固件下载)
sudo ufw allow 10086/tcp   # 设备网关 (直连)
sudo ufw allow 1883/tcp    # MQTT (直连)
sudo ufw allow 8883/tcp    # MQTTS (直连)
# 注意: 10088/10089 不需要开放，已绑定127.0.0.1，通过Nginx反代访问

# firewalld（CentOS）
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=10086/tcp
sudo firewall-cmd --permanent --add-port=1883/tcp
sudo firewall-cmd --permanent --add-port=8883/tcp
sudo firewall-cmd --reload
```

### C. 技术支持

- **项目仓库**: https://github.com/hhtbing-wisefido/OTA-QL（私有）
- **部署脚本下载**: https://github.com/hhtbing-wisefido/public-data/tree/main/OTA-QL-data

---

### 6.7 多域名证书申请与部署（v5.2 新增）

v5.3 起，部署时的 SSL 证书配置改为交互式菜单，用户可选择七种方式：

| 选项 | 方式 | 说明 |
|------|------|------|
| 1 | 搜索已有证书 | 从宝塔/1Panel/Certbot等17种面板路径搜索已申请的证书 |
| 2 | 申请通配符证书 | `*.domain.com` 覆盖所有子域名（需DNS验证） |
| 3 | 申请SAN多域名证书 | 指定多个域名写入同一张证书（支持HTTP/DNS验证） |
| 4 | 查询证书覆盖情况 | 检查当前证书SAN是否覆盖回调地址/网关/Web面板 |
| 5 | 交互式申请SAN证书 | 引导式填写域名+选择验证方式，一键申请 |
| 6 | 交互式申请通配符证书 | 引导式填写基础域名+DNS验证指引，一键申请 |
| 0 | 跳过 | 使用自签名证书，ESP32可能无法连接 |

**通配符证书申请示例：**

```bash
# 脚本自动执行，certbot 会要求添加 DNS TXT 记录
sudo certbot certonly --manual --preferred-challenges dns \
    -d "*.wisefido.com" -d "wisefido.com"

# 成功后证书 SAN: *.wisefido.com
# 覆盖: ota.wisefido.com, api.wisefido.com, 任意 xxx.wisefido.com
```

**SAN 多域名证书申请示例：**

```bash
# HTTP 验证（需要端口80空闲）
sudo certbot certonly --standalone \
    -d ota.wisefido.com -d ota.wisefido.work

# DNS 验证（不占用端口）
sudo certbot certonly --manual --preferred-challenges dns \
    -d ota.wisefido.com -d ota.wisefido.work

# 成功后证书 SAN: ota.wisefido.com, ota.wisefido.work
```

**失败重试机制：** 当选择的方式失败后，脚本会提示尝试其他方式，全部失败后跳过证书配置继续部署（使用自签名证书）。

### 6.8 跨域名证书部署详解（v5.3 新增）

#### 什么是"跨域名证书部署"？

**一句话说明**：用一张 SSL 证书同时服务多个域名，让所有域名的 ESP32 设备都能通过 TLS 验证。

#### 为什么需要跨域名？

典型场景：生产域名 `ota.wisefido.com` 和测试域名 `ota.wisefido.work` 指向同一台服务器。OTA-QL Go 服务器只加载**一份证书文件**（`/opt/ota-ql/certs/fullchain.pem`），如果证书只包含一个域名，另一个域名的设备连接时 TLS 握手会失败。

#### 三种解决方案

| 方案 | 证书类型 | 覆盖域名 | 限制 | 推荐场景 |
|------|---------|---------|------|---------|
| **方案A** | SAN多域名证书 | 精确指定的域名列表 | 需逐个列出域名 | 不同基础域名（.com + .work） |
| **方案B** | 通配符证书 | `*.domain.com` 所有子域名 | 只能覆盖**同一基础域名** | 同一域名下多个子域名 |
| **方案C** | 两张独立证书 | 各自覆盖一个域名 | OTA-QL只能加载一张 | ❌ 不适用 |

#### 方案A详解：SAN多域名证书（推荐）

**适用场景**：`ota.wisefido.com` + `ota.wisefido.work`（不同基础域名）

```bash
# 步骤1: 用 certbot 申请包含两个域名的证书
sudo certbot certonly --standalone \
    -d ota.wisefido.com -d ota.wisefido.work

# 步骤2: 证书生成位置
/etc/letsencrypt/live/ota.wisefido.com/fullchain.pem
/etc/letsencrypt/live/ota.wisefido.com/privkey.pem

# 步骤3: 部署到 OTA-QL
sudo cp /etc/letsencrypt/live/ota.wisefido.com/fullchain.pem /opt/ota-ql/certs/
sudo cp /etc/letsencrypt/live/ota.wisefido.com/privkey.pem /opt/ota-ql/certs/
docker restart ota-ql
```

**验证证书SAN覆盖：**

```bash
openssl x509 -in /opt/ota-ql/certs/fullchain.pem -noout -text | grep -A1 "Subject Alternative Name"
# 应显示: DNS:ota.wisefido.com, DNS:ota.wisefido.work
```

**数据流：**

```
设备A（NVS server=ota.wisefido.com）→ :10086 认证 → 回调 ota.wisefido.com:8883
设备B（NVS server=ota.wisefido.work）→ :10086 认证 → 回调 ota.wisefido.com:8883

证书SAN: ota.wisefido.com + ota.wisefido.work
  → ESP32 连 :8883 用 ota.wisefido.com → 匹配SAN → ✅ TLS通过
  → ESP32 连 :10086 用 ota.wisefido.work → 匹配SAN → ✅ TLS通过
```

#### 方案B详解：通配符证书

**适用场景**：同一基础域名下多个子域名（如 `ota.wisefido.com` + `api.wisefido.com`）

```bash
# 申请通配符证书（必须使用DNS验证）
sudo certbot certonly --manual --preferred-challenges dns \
    -d "*.wisefido.com" -d "wisefido.com"

# certbot 会要求添加 DNS TXT 记录:
#   _acme-challenge.wisefido.com → TXT → (certbot提供的值)
# 到域名管理面板（阿里云/腾讯云/Cloudflare）添加后按回车继续
```

> ⚠️ **重要限制**：`*.wisefido.com` 只覆盖 `.wisefido.com` 的子域名。如果还有 `.wisefido.work` 域名，需要额外用 SAN 证书或再申请一张 `*.wisefido.work` 的通配符证书。

#### 使用脚本菜单操作（推荐）

**方式一：部署时交互式菜单**

```
部署选择 SSL 证书配置
  → 选择 5. 交互式申请 SAN 多域名证书
  → 输入: ota.wisefido.com ota.wisefido.work
  → 选择验证方式（HTTP/DNS/Nginx）
  → certbot 自动申请并部署
```

**方式二：SSL证书管理菜单（菜单11）**

```
菜单 11. SSL证书管理
  → 7. 查询证书覆盖情况   ← 先检查当前证书覆盖了哪些域名
  → 8. 交互式申请 SAN 证书  ← 申请覆盖多域名的新证书
  → 9. 交互式申请通配符证书  ← 或申请覆盖所有子域名的证书
```

**方式三：跨域名证书部署（菜单11 → 6）**

```
菜单 11. SSL证书管理 → 6. 跨域名证书部署
  → 自动搜索系统中所有证书
  → 显示每张证书的 SAN 域名列表
  → 标注 ✓ 覆盖回调域名 / ⚠ 未覆盖
  → 选择一张覆盖最多域名的证书部署
```

#### 证书覆盖检查功能（v5.3 新增）

部署时或任何时候可通过菜单检查当前证书是否覆盖所有服务地址：

```
SSL 证书覆盖检查 (v5.3)

[证书基本信息]
  CN:     ota.wisefido.com
  颁发者: R11
  到期:   Mar 15 2026
  SAN 域名 (2个):
    • ota.wisefido.com
    • ota.wisefido.work

[服务地址覆盖检查]

  ① 设备回调地址（MQTT Broker）
      地址: ota.wisefido.com:8883
      状态: ✓ 已覆盖 — 证书SAN包含此域名

  ② 设备认证网关（cmux 网关）
      地址: ota.wisefido.com:10086
      状态: ✓ 已覆盖 — 证书SAN包含此域名

  ③ Web管理面板（HTTPS）
      说明: 生产环境通过 Nginx :443 反代，Nginx用自己的证书

[覆盖总结]
  ✓ 所有服务域名均被证书覆盖，ESP32设备可正常连接
```

---

## 12. 服务器部署及反代设置（v8.9 新增）

### 12.1 架构概述

v8.9 起，OTA-QL 采用 **Nginx 反向代理 + Docker 容器** 的生产部署架构。HTTP 管理面板和固件下载服务均绑定 `127.0.0.1`，通过 Nginx 提供对外 HTTPS 访问；设备协议端口（cmux 网关/MQTT/MQTTS）直连公网。

```
公网用户/ESP32设备
│
├── :443    ─── HTTPS ──── Nginx反代 → 127.0.0.1:10088 ── Web管理面板 + REST API
├── :443/firmware ── HTTPS ── Nginx反代 → 127.0.0.1:10089 ── HTTP固件下载 (ESP32 OTA)
├── :10086  ─── TCP/TLS ── Docker直连 (0.0.0.0) ────────── 设备接入网关 (cmux)
├── :1883   ─── MQTT ───── Docker直连 (0.0.0.0) ────────── MQTT Broker (明文)
└── :8883   ─── MQTTS ──── Docker直连 (0.0.0.0) ────────── MQTTS Broker (TLS)
```

### 12.2 端口绑定策略

| 端口 | 绑定地址 | 对外可访问 | 访问方式 | 说明 |
|------|---------|-----------|---------|------|
| 10088 | 127.0.0.1 | ❌ | Nginx :443 反代 | Web管理面板 + API |
| 10089 | 127.0.0.1 | ❌ | Nginx :443/firmware 反代 | ESP32 固件下载 |
| 10086 | 0.0.0.0 | ✅ | 设备直连 | cmux 设备网关 |
| 1883 | 0.0.0.0 | ✅ | 设备直连 | MQTT Broker |
| 8883 | 0.0.0.0 | ✅ | 设备直连 | MQTTS Broker |

> 💡 **安全优势**：10088/10089 不暴露到公网，防火墙无需开放这两个端口。

### 12.3 Nginx 反向代理配置

#### 12.3.1 完整 Nginx 配置文件

```nginx
# /etc/nginx/sites-available/ota-ql
# 或宝塔面板中对应站点的配置

# ---- HTTPS (443) ----
server {
    listen 443 ssl http2;
    server_name ota.wisefido.com ota.wisefido.work;

    # Let's Encrypt 正式证书
    ssl_certificate     /etc/letsencrypt/live/ota.wisefido.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ota.wisefido.com/privkey.pem;

    # SSL优化
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;

    # Web管理面板 + API（反代到Go HTTPS端口）
    location / {
        proxy_pass https://127.0.0.1:10088;
        proxy_ssl_verify off;      # Go使用自签证书，跳过验证
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket 支持（日志实时推送等）
    location /ws {
        proxy_pass https://127.0.0.1:10088;
        proxy_ssl_verify off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 固件下载（v8.9: 反代到HTTP固件端口，大文件优化）
    location /firmware {
        proxy_pass http://127.0.0.1:10089;
        proxy_read_timeout 600s;
        proxy_buffering off;        # 大文件不缓冲
    }
}

# ---- HTTP → HTTPS 重定向 ----
server {
    listen 80;
    server_name ota.wisefido.com ota.wisefido.work;
    return 301 https://$host$request_uri;
}
```

#### 12.3.2 宝塔面板配置方法

如果使用**宝塔面板**管理 Nginx，按以下步骤配置：

**步骤一：Web 管理面板反代（:443 → :10088）**

1. 打开宝塔面板 → 网站 → 选择 `ota.wisefido.com` 站点
2. 点击 **反向代理** → **添加反向代理**
3. 配置：
   - 代理名称：`ota-web`
   - 目标URL：`https://127.0.0.1:10088`
   - 发送域名：`$host`

**步骤二：固件下载反代（:443/firmware → :10089）**

1. 在同一站点 → **反向代理** → **添加反向代理**
2. 配置：
   - 代理名称：`ota-firmware`
   - 目标URL：`http://127.0.0.1:10089`
   - 代理目录：`/firmware`（⚠️ **必须填写**）

> 📌 **验证方法**：浏览器访问 `https://ota.wisefido.com/firmware`，应返回 `{"error":"缺少文件名"}` 或 HTTP 400，表示反代配置成功。

**步骤三：SSL 证书**

1. 在站点设置 → **SSL** → 使用 Let's Encrypt 申请证书
2. 勾选 `ota.wisefido.com` 和 `ota.wisefido.work`（如需双域名）
3. 申请成功后自动续期

### 12.4 固件下载域名配置

#### 12.4.1 什么是固件下载域名？

`OTA_FIRMWARE_URL_BASE` 环境变量决定了 OTA 推送消息中固件下载的 URL 前缀。ESP32 设备收到 OTA 升级指令后，会从这个地址下载固件文件。

```
v8.9 之前:  http://ota.wisefido.com:10089/firmware/xxx.bin  (HTTP直连)
v8.9 之后:  https://ota.wisefido.com/firmware/xxx.bin        (HTTPS Nginx反代)
```

#### 12.4.2 部署脚本配置方式

**方式一：部署时自动提示**

执行菜单 1（生产部署）或 13（测试部署）时，脚本会在设置回调地址后提示：

```
=========================================
  固件下载域名设置 (v8.9)
=========================================

什么是固件下载域名？
  ESP32 设备 OTA 升级时，从此域名下载固件文件。
  服务器会设置环境变量:
    OTA_FIRMWARE_URL_BASE=https://<域名>/firmware

  ⚠️  使用此功能前，请确保 Nginx 已配置 /firmware 反代:

  ┌──────────────────────────────────────────────────┐
  │  Nginx 反向代理配置 (必须先完成)                  │
  ├──────────────────────────────────────────────────┤
  │  location /firmware {                             │
  │      proxy_pass http://127.0.0.1:10089;          │
  │      proxy_read_timeout 600s;                     │
  │      proxy_buffering off;                         │
  │  }                                                │
  └──────────────────────────────────────────────────┘

请输入固件下载域名: ota.wisefido.com
[SUCCESS] 固件下载域名已设置: ota.wisefido.com
```

**方式二：菜单 14 设置与查看**

选择菜单 14 进入子菜单：
- **子菜单 1**：设置/修改固件下载域名，修改后提示是否重启容器
- **子菜单 2**：查看当前固件域名及派生的固件 URL、Nginx 配置说明

#### 12.4.3 环境变量传递

```
.firmware_domain 文件 → 部署脚本读取 → Docker -e OTA_FIRMWARE_URL_BASE=https://<域名>/firmware
                                                ↓
                                        Go 服务器 main.go
                                                ↓
                                        OTA 推送消息中的 firmwareURL 字段
                                                ↓
                                        ESP32 设备从此 URL 下载固件
```

### 12.5 完整部署检查清单

部署完成后，按以下清单逐项验证：

| # | 检查项 | 验证命令/方法 | 预期结果 |
|---|-------|-------------|---------|
| 1 | Docker 容器运行 | `docker ps -f name=ota-ql` | 状态 Up |
| 2 | Nginx 反代 Web 管理 | 浏览器访问 `https://ota.wisefido.com/` | 显示登录页面 |
| 3 | Nginx 反代固件下载 | 浏览器访问 `https://ota.wisefido.com/firmware` | 返回 `{"error":"缺少文件名"}` |
| 4 | 10088 不可公网访问 | `curl -sk https://<公网IP>:10088/` | 连接拒绝 |
| 5 | 10089 不可公网访问 | `curl http://<公网IP>:10089/` | 连接拒绝 |
| 6 | cmux 网关直连 | `telnet ota.wisefido.com 10086` | 连接成功 |
| 7 | MQTT 直连 | `telnet ota.wisefido.com 1883` | 连接成功 |
| 8 | MQTTS 直连 | `telnet ota.wisefido.com 8883` | 连接成功 |
| 9 | SSL 证书有效 | `echo | openssl s_client -connect ota.wisefido.com:443 2>/dev/null | openssl x509 -noout -dates` | 证书未过期 |
| 10 | 固件域名已配置 | 脚本菜单 3 查看部署信息 | 显示固件域名和URL |

### 12.6 防火墙配置（v8.9 更新）

```bash
# 需要开放的端口（v8.9）
443/tcp      # Nginx HTTPS（Web管理 + 固件下载）
10086/tcp    # 设备接入网关 (cmux, 直连)
1883/tcp     # MQTT Broker (直连)
8883/tcp     # MQTTS Broker (直连)
80/tcp       # HTTP → HTTPS 重定向（可选）

# 不需要开放的端口（已绑定127.0.0.1）
# 10088/tcp  — Web管理（通过Nginx 443反代）
# 10089/tcp  — 固件下载（通过Nginx 443/firmware反代）
```

### 12.7 常见问题

#### Q: 为什么 10086/1883/8883 不能用 Nginx 反代？

这些端口使用**非 HTTP 协议**（TCP/MQTT），Nginx `http` 块无法处理。虽然 Nginx `stream` 块可以做四层透传，但 Docker 直接暴露端口更简单可靠，无需额外配置。

#### Q: ESP32 设备能通过 HTTPS 下载固件吗？

可以。v8.9 通过 Nginx `/firmware` 反代实现：
- ESP32 请求 `https://ota.wisefido.com/firmware/xxx.bin`
- Nginx 443 接收请求 → 转发到 `http://127.0.0.1:10089/firmware/xxx.bin`
- Go HTTP 固件服务返回文件
- Nginx 使用 Let's Encrypt 证书加密传输给 ESP32

#### Q: 宝塔面板中看不到 `/firmware` 反代怎么办？

在宝塔面板 → 网站 → 反向代理中，确保"代理目录"填写了 `/firmware`。如果宝塔版本较旧不支持路径代理，可手动编辑 Nginx 配置文件，在 `server` 块中添加 `location /firmware` 块。

#### Q: 从旧版本升级到 v8.9 需要做什么？

1. 更新部署脚本（wget 最新版本）
2. 运行脚本菜单 1 重新部署
3. 脚本会自动提示配置固件下载域名
4. **手动配置 Nginx `/firmware` 反代**（脚本会提示 Nginx 配置方法）
5. 防火墙**关闭** 10089 端口（不再需要）

---

> ⚡ **版本历史**:
> **v8.9** (2026-03-08) — 新增第12章"服务器部署及反代设置"；固件下载(10089)改为127.0.0.1绑定+Nginx /firmware反代；新增菜单14固件下载域名管理；OTA_FIRMWARE_URL_BASE环境变量；端口表/防火墙/Docker Compose全面更新
> **v5.3** (2026-03-08) — SSL证书管理菜单扩展至9项（新增覆盖检查/交互式SAN/交互式通配符），部署菜单扩展至7项，新增跨域名证书部署详解（6.8章节）
> **v5.2** (2026-03-08) — 部署时SSL证书配置改为交互式菜单（搜索已有/通配符/SAN多域名），新增多域名证书申请指导
> **v5.1** (2026-03-08) — 修复证书搜索重复误报BUG（realpath去重），新增跨域名证书部署（菜单11→子菜单6）
> **v5.0** (2026-03-08) — 新增 SSL 证书管理（章节6 + 菜单11），内置17种面板路径数据库，部署时自动搜索并部署证书
> **v4.6** (2026-03-08) — 菜单10增加子菜单（设置与查看），支持查看回调地址详情及派生服务地址
