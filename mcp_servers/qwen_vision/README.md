# Qwen Vision MCP Server

基于 **Qwen3.7-Plus**（阿里云百炼）的图片分析 MCP 服务器。

## 功能

| 工具 | 说明 |
|------|------|
| `analyze_image` | AI 视觉分析单张截图，返回 UI 布局描述 |
| `compare_images` | AI 视觉对比两张截图（如 Android vs iOS） |
| `pixel_diff` | OpenCV 像素级精确对比，返回 SSIM 相似度 + 差异坐标 |

## 安装

### 1. 安装依赖

```bash
pip install mcp httpx opencv-python numpy
```

### 2. 获取 API Key

去 [阿里云百炼控制台](https://bailian.console.aliyun.com) 创建 API Key（免费额度百万 token/月）。

### 3. 配置 Claude Code

在 `~/.claude/mcp.json` 或项目 `.mcp.json` 中添加：

```json
{
  "mcpServers": {
    "qwen-vision": {
      "type": "stdio",
      "command": "python",
      "args": ["<本机路径>/mcp_servers/qwen_vision/server.py"],
      "env": {
        "DASHSCOPE_API_KEY": "sk-你的API-KEY"
      }
    }
  }
}
```

### 4. 重启 Claude Code

重启后即可使用。发送截图到对话框，AI 自动分析。

## 注意事项

- API Key 为敏感信息，**不要**提交到公开仓库
- 图片通过 base64 编码上传至阿里云百炼 API
- `pixel_diff` 工具纯本地运行，不消耗 API 额度
- 支持中文路径的图片文件
