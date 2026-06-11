#!/usr/bin/env python3
"""
Qwen Vision MCP Server 启动器
- 首次运行自动从 GitHub 拉取最新代码
- 之后每次启动自动 git pull 更新
- 可在任何机器上使用，只需 Python + Git
"""

import subprocess
import sys
import os
from pathlib import Path

REPO_URL = "https://github.com/hhtbing/public-data"
REPO_DIR = Path.home() / ".claude" / "qwen-vision-mcp"
SERVER = REPO_DIR / "mcp_servers" / "qwen_vision" / "server.py"


PROXY = os.environ.get("ALL_PROXY", "socks5://127.0.0.1:4000")


def git_env():
    """带代理的 Git 环境变量"""
    return {**os.environ, "ALL_PROXY": PROXY, "http_proxy": PROXY, "https_proxy": PROXY}


def main():
    if not REPO_DIR.exists():
        print(f"[launcher] 首次运行，从 GitHub 下载 MCP Server...", file=sys.stderr)
        result = subprocess.run(
            ["git", "clone", "--depth", "1", REPO_URL, str(REPO_DIR)],
            env=git_env(),
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            print(f"[launcher] 下载失败: {result.stderr}", file=sys.stderr)
            sys.exit(1)
        print(f"[launcher] 下载完成: {REPO_DIR}", file=sys.stderr)
    else:
        print(f"[launcher] 检查更新...", file=sys.stderr)
        result = subprocess.run(
            ["git", "-C", str(REPO_DIR), "pull", "--ff-only"],
            env=git_env(),
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            print(f"[launcher] 已是最新版本", file=sys.stderr)
        else:
            print(f"[launcher] 更新跳过（可能已离线）", file=sys.stderr)

    # 启动真正的 MCP Server
    print(f"[launcher] 启动服务: {SERVER}", file=sys.stderr)
    os.execv(sys.executable, [sys.executable, str(SERVER)])


if __name__ == "__main__":
    main()
