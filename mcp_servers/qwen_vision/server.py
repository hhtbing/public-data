#!/usr/bin/env python3
"""
Qwen Vision MCP Server — Qwen3.7-Plus 图像分析服务

通过阿里云百炼 DashScope API 调用 Qwen3.7-Plus 视觉模型，
提供 UI 截图分析和对比能力。

使用方式 (Claude Code 自动启动):
    .mcp.json 配置后自动通过 stdio 调用

环境变量:
    DASHSCOPE_API_KEY — 阿里云百炼 API Key
"""

import sys
import os
import json
import base64
import logging
import asyncio
from pathlib import Path
from typing import Any

import httpx
import cv2
import numpy as np

# === 日志全部输出到 stderr（stdout 给 JSON-RPC 用） ===
logging.basicConfig(
    stream=sys.stderr,
    level=logging.INFO,
    format="[qwen-vision] %(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

# === 配置 ===
DASHSCOPE_API_KEY = os.environ.get("DASHSCOPE_API_KEY", "")
BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
MODEL = "qwen3.7-plus"  # 最新多模态智能体模型
MAX_TOKENS = 2000
HTTP_TIMEOUT = 90.0  # 大图推理需要更多时间

# === MCP SDK ===
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

app = Server("qwen-vision")

# ============================================================
# 工具注册
# ============================================================

@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="analyze_image",
            description=(
                "使用 Qwen3.7-Plus 视觉模型分析单张截图/图片。"
                "返回详细的 UI 布局描述，包括元素位置、颜色、文字、间距等。"
                "适用于：理解界面结构、检查 UI 元素、提取文字信息。"
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "image_path": {
                        "type": "string",
                        "description": "图片文件的绝对路径（支持 PNG/JPG/JPEG）",
                    },
                    "question": {
                        "type": "string",
                        "description": "针对图片的具体问题。留空则返回完整 UI 描述。",
                    },
                },
                "required": ["image_path"],
            },
        ),
        Tool(
            name="compare_images",
            description=(
                "使用 Qwen3.7-Plus 对比两张截图（如 Android vs iOS）。"
                "识别布局、颜色、文字、间距、图标等方面的差异。"
                "以 iOS 为基准，列出所有不一致之处。"
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "image_path_1": {
                        "type": "string",
                        "description": "第一张图片的绝对路径（通常是 Android 截图）",
                    },
                    "image_path_2": {
                        "type": "string",
                        "description": "第二张图片的绝对路径（通常是 iOS 参考截图）",
                    },
                    "focus": {
                        "type": "string",
                        "description": "对比重点：layout(布局) / colors(颜色) / spacing(间距) / text(文字) / icons(图标) / all(全部，默认)",
                        "default": "all",
                    },
                },
                "required": ["image_path_1", "image_path_2"],
            },
        ),
        Tool(
            name="pixel_diff",
            description=(
                "像素级精确对比两张截图（Android vs iOS）。"
                "使用计算机视觉算法（SSIM + 轮廓检测）定位每个差异区域，"
                "返回像素坐标、差异百分比和差异位置列表。"
                "适用于 UI 像素级对齐验证。"
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "image_path_1": {
                        "type": "string",
                        "description": "第一张图片的绝对路径（通常是 Android 截图）",
                    },
                    "image_path_2": {
                        "type": "string",
                        "description": "第二张图片的绝对路径（通常是 iOS 参考截图）",
                    },
                    "sensitivity": {
                        "type": "number",
                        "description": "差异检测灵敏度 (0-1)，越小越敏感。默认 0.05 适合 UI 对比",
                        "default": 0.05,
                    },
                },
                "required": ["image_path_1", "image_path_2"],
            },
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    try:
        if name == "analyze_image":
            return await _handle_analyze(arguments)
        elif name == "compare_images":
            return await _handle_compare(arguments)
        elif name == "pixel_diff":
            return await _handle_pixel_diff(arguments)
        else:
            return [TextContent(type="text", text=f"❌ 未知工具: {name}")]
    except Exception as e:
        log.error(f"Tool '{name}' failed: {e}", exc_info=True)
        return [TextContent(type="text", text=f"❌ 执行失败: {str(e)}")]


# ============================================================
# 工具实现
# ============================================================

async def _handle_analyze(args: dict) -> list[TextContent]:
    image_path = args["image_path"]
    question = args.get("question", "").strip()

    # 校验文件
    if not Path(image_path).exists():
        return [TextContent(type="text", text=f"❌ 文件不存在: {image_path}")]

    b64 = _encode_image(image_path)
    filename = Path(image_path).name

    if not question:
        question = """请作为UI审查专家，详细分析这张手机截图：

1. 【整体布局】页面结构（导航栏/内容区/底部栏），各区域比例
2. 【UI 元素】逐一列出所有可见元素（按钮、文本、图标、输入框、卡片等）
3. 【颜色】说明关键元素的颜色（背景色、文字色、强调色）
4. 【文字】所有可见的文字内容及大致字号
5. 【间距】元素之间的间距和对齐关系
6. 【异常】任何看起来不对齐、被裁切或显示异常的地方

请用中文，尽可能精确。"""

    log.info(f"Analyzing: {filename}")
    response = await _call_vision(question, b64)
    log.info(f"Analysis complete: {filename} — {len(response)} chars")
    return [TextContent(type="text", text=response)]


async def _handle_compare(args: dict) -> list[TextContent]:
    img1 = args["image_path_1"]
    img2 = args["image_path_2"]
    focus = args.get("focus", "all")

    for p in [img1, img2]:
        if not Path(p).exists():
            return [TextContent(type="text", text=f"❌ 文件不存在: {p}")]

    b64_1 = _encode_image(img1)
    b64_2 = _encode_image(img2)
    name1 = Path(img1).name
    name2 = Path(img2).name

    focus_map = {
        "layout": "布局结构和元素位置",
        "colors": "颜色（背景色、文字色、强调色等）",
        "spacing": "间距、边距、对齐方式",
        "text": "文字内容、字号、字体粗细",
        "icons": "图标样式、大小、颜色",
        "all": "布局、颜色、间距、文字、图标等所有方面",
    }
    focus_desc = focus_map.get(focus, focus_map["all"])

    prompt = f"""你是专业的移动端UI审查专家。请严格对比这两张截图：

📱 图1（待验证）: {name1}
📱 图2（iOS基准）: {name2}

请重点关注 **{focus_desc}** 方面的差异。

输出格式：
## 发现的差异
（逐条列出，每条标注严重程度：🔴严重/🟡中等/🟢轻微）

## 总结
（以 iOS 为准，概括需要修改的内容）

如果没有差异，请直接说「✅ 两张截图完全一致，未发现差异」。
请用中文回答。"""

    log.info(f"Comparing: {name1} vs {name2} (focus={focus})")
    response = await _call_vision_multi(prompt, [b64_1, b64_2])
    log.info(f"Compare complete — {len(response)} chars")
    return [TextContent(type="text", text=response)]


# ============================================================
# 像素级对比（OpenCV — 不需要 API，纯本地计算）
# ============================================================

def _compute_ssim(img1: np.ndarray, img2: np.ndarray) -> float:
    """手动计算 SSIM (Structural Similarity Index)"""
    C1 = (0.01 * 255) ** 2
    C2 = (0.03 * 255) ** 2
    img1 = img1.astype(np.float64)
    img2 = img2.astype(np.float64)
    mu1 = cv2.GaussianBlur(img1, (11, 11), 1.5)
    mu2 = cv2.GaussianBlur(img2, (11, 11), 1.5)
    mu1_sq = mu1 ** 2
    mu2_sq = mu2 ** 2
    mu1_mu2 = mu1 * mu2
    sigma1_sq = cv2.GaussianBlur(img1 ** 2, (11, 11), 1.5) - mu1_sq
    sigma2_sq = cv2.GaussianBlur(img2 ** 2, (11, 11), 1.5) - mu2_sq
    sigma12 = cv2.GaussianBlur(img1 * img2, (11, 11), 1.5) - mu1_mu2
    ssim_map = ((2 * mu1_mu2 + C1) * (2 * sigma12 + C2)) / \
               ((mu1_sq + mu2_sq + C1) * (sigma1_sq + sigma2_sq + C2))
    return float(np.mean(ssim_map))


async def _handle_pixel_diff(args: dict) -> list[TextContent]:
    img1_path = args["image_path_1"]
    img2_path = args["image_path_2"]
    sensitivity = float(args.get("sensitivity", 0.05))

    for p in [img1_path, img2_path]:
        if not Path(p).exists():
            return [TextContent(type="text", text=f"文件不存在: {p}")]

    name1 = Path(img1_path).name
    name2 = Path(img2_path).name

    try:
        # 用 imdecode 避免中文路径问题
        img1 = cv2.imdecode(np.fromfile(img1_path, dtype=np.uint8), cv2.IMREAD_COLOR)
        img2 = cv2.imdecode(np.fromfile(img2_path, dtype=np.uint8), cv2.IMREAD_COLOR)
        if img1 is None: return [TextContent(type="text", text=f"无法读取: {img1_path}")]
        if img2 is None: return [TextContent(type="text", text=f"无法读取: {img2_path}")]

        h = max(img1.shape[0], img2.shape[0])
        w = max(img1.shape[1], img2.shape[1])
        img1 = cv2.resize(img1, (w, h))
        img2 = cv2.resize(img2, (w, h))

        gray1 = cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY)
        gray2 = cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY)

        ssim_score = _compute_ssim(gray1, gray2)

        diff = cv2.absdiff(gray1, gray2)
        thresh_val = int(sensitivity * 255)
        _, thresh = cv2.threshold(diff, thresh_val, 255, cv2.THRESH_BINARY)

        diff_pixels = int(np.sum(thresh == 255))
        total_pixels = thresh.size
        diff_percent = diff_pixels / total_pixels * 100

        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 9))
        dilated = cv2.dilate(thresh, kernel, iterations=2)

        contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        contours = sorted(contours, key=cv2.contourArea, reverse=True)

        regions = []
        min_area = (w * h) * 0.0001
        for i, cnt in enumerate(contours[:30]):
            area = cv2.contourArea(cnt)
            if area < min_area: break
            x, y, bw, bh = cv2.boundingRect(cnt)
            roi_diff = thresh[y:y+bh, x:x+bw]
            roi_pct = np.sum(roi_diff == 255) / roi_diff.size * 100
            regions.append({
                "index": i + 1,
                "x": int(x), "y": int(y),
                "width": int(bw), "height": int(bh),
                "center_x": int(x + bw // 2),
                "center_y": int(y + bh // 2),
                "area_px": int(area),
                "diff_in_region_pct": round(roi_pct, 1),
            })

        # 保存差异可视化
        out_dir = Path(img1_path).parent
        diff_vis_path = str(out_dir / f"pixel_diff_{name1}_vs_{name2}.png")
        diff_color = cv2.cvtColor(thresh, cv2.COLOR_GRAY2BGR)
        diff_color[thresh == 255] = [0, 0, 255]
        overlay = cv2.addWeighted(img1, 0.5, diff_color, 0.5, 0)
        for r in regions[:10]:
            cv2.rectangle(overlay, (r["x"], r["y"]),
                         (r["x"] + r["width"], r["y"] + r["height"]), (0, 255, 0), 3)
            cv2.putText(overlay, str(r["index"]), (r["x"] + 5, r["y"] + 25),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        # 保存差异可视化 (用 imencode 避免中文路径)
        _, buf = cv2.imencode('.png', overlay)
        with open(diff_vis_path, 'wb') as f:
            f.write(buf)

        quality = ("优秀" if ssim_score >= 0.98 else "良好" if ssim_score >= 0.95
                   else "一般" if ssim_score >= 0.90 else "差异较大" if ssim_score >= 0.80
                   else "严重不一致")

        lines = [
            "# 像素级对比报告",
            "",
            f"| 图1 (待验证) | 图2 (基准) |",
            f"||--------------|-------------|",
            f"| `{name1}` | `{name2}` |",
            "",
            "## 整体指标",
            f"| 指标 | 值 |",
            f"||------|-----|",
            f"| SSIM 相似度 | **{ssim_score:.4f}** ({quality}) |",
            f"| 像素差异率 | **{diff_percent:.2f}%** ({diff_pixels:,} / {total_pixels:,} px) |",
            f"| 图片尺寸 | {w} x {h} px |",
            f"| 差异区域数 | **{len(regions)} 个** |",
            "",
        ]

        if regions:
            lines.append("## 差异区域（按面积降序）")
            lines.append("")
            lines.append("| # | 位置 (x,y) | 大小 (w x h) | 中心坐标 | 面积(px) | 区域内差异% |")
            lines.append("||--|-----------|-------------|---------|---------|-----------|")
            for r in regions:
                lines.append(
                    f"| {r['index']} | ({r['x']}, {r['y']}) | "
                    f"{r['width']} x {r['height']} | "
                    f"({r['center_x']}, {r['center_y']}) | "
                    f"{r['area_px']} | {r['diff_in_region_pct']}% |"
                )
            lines.append("")
            lines.append(f"> 差异可视化图: `{diff_vis_path}`")
        else:
            lines.append("## 完全一致，未检测到像素级差异。")

        report = "\n".join(lines)
        log.info(f"Pixel diff OK: SSIM={ssim_score:.4f}, diff={diff_percent:.2f}%, regions={len(regions)}")
        return [TextContent(type="text", text=report)]

    except Exception as e:
        log.error(f"Pixel diff error: {e}", exc_info=True)
        return [TextContent(type="text", text=f"像素对比失败: {str(e)}")]


# ============================================================
# 核心：调用 Qwen3.7-Plus API
# ============================================================

def _encode_image(path: str) -> str:
    """读取图片并编码为 base64"""
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def _get_mime_type(path: str) -> str:
    """根据扩展名推断 MIME 类型"""
    ext = Path(path).suffix.lower()
    return {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".bmp": "image/bmp",
    }.get(ext, "image/png")


async def _call_vision(prompt: str, b64_image: str) -> str:
    """单图分析"""
    mime = "image/png"  # 默认
    return await _call_api(prompt, [b64_image], [mime])


async def _call_vision_multi(prompt: str, b64_images: list[str]) -> str:
    """多图对比"""
    mimes = ["image/png"] * len(b64_images)
    return await _call_api(prompt, b64_images, mimes)


async def _call_api(prompt: str, b64_images: list[str], mimes: list[str]) -> str:
    """调用阿里百炼 OpenAI 兼容接口"""
    if not DASHSCOPE_API_KEY:
        return (
            "❌ 未配置 DASHSCOPE_API_KEY 环境变量。\n"
            "请在 .mcp.json 的 env 中设置，或在终端执行:\n"
            '  export DASHSCOPE_API_KEY="sk-xxxxx"'
        )

    # 构造多模态消息
    content: list[dict] = [{"type": "text", "text": prompt}]
    for b64, mime in zip(b64_images, mimes):
        content.append({
            "type": "image_url",
            "image_url": {"url": f"data:{mime};base64,{b64}"},
        })

    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": content}],
        "max_tokens": MAX_TOKENS,
    }

    headers = {
        "Authorization": f"Bearer {DASHSCOPE_API_KEY}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=HTTP_TIMEOUT) as client:
        resp = await client.post(
            f"{BASE_URL}/chat/completions",
            headers=headers,
            json=payload,
        )

        if resp.status_code != 200:
            log.error(f"API error {resp.status_code}: {resp.text[:500]}")
            return f"❌ API 错误 ({resp.status_code}): {resp.text[:300]}"

        data = resp.json()

        if "choices" not in data or not data["choices"]:
            log.error(f"Unexpected API response: {json.dumps(data, ensure_ascii=False)[:500]}")
            return f"❌ API 返回异常: {json.dumps(data, ensure_ascii=False)[:300]}"

        return data["choices"][0]["message"]["content"]


# ============================================================
# 入口
# ============================================================

async def main():
    async with stdio_server() as (read, write):
        await app.run(read, write, app.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
