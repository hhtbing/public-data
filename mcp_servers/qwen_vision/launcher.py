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


def main():
    # 自动安装 / 更新
    if not REPO_DIR.exists():
        print(f"[launcher] 首次运行，正在下载 MCP Server...", file=sys.stderr)
        subprocess.run(
            ["git", "clone", "--depth", "1", REPO_URL, str(REPO_DIR)],
            check=True,
            capture_output=True,
        )
        print(f"[launcher] 下载完成: {REPO_DIR}", file=sys.stderr)
    else:
        print(f"[launcher] 检查更新...", file=sys.stderr)
        subprocess.run(
            ["git", "-C", str(REPO_DIR), "pull", "--ff-only"],
            check=False,
            capture_output=True,
        )

    # 启动真正的 MCP Server
    print(f"[launcher] 启动服务: {SERVER}", file=sys.stderr)
    os.execv(sys.executable, [sys.executable, str(SERVER)])


if __name__ == "__main__":
    main()
