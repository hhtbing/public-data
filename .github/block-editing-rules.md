# 块编辑系统规则

## 核心原则

### 1. 不要走捷径，解决本质问题
- ❌ 错误：删除容器块来避免事件冒泡
- ✅ 正确：修复事件处理逻辑，让容器和图标都可编辑但互不干扰

### 2. 完整细分，不遗漏任何元素
- ✅ 所有容器必须有data-content（可编辑容器属性）
- ✅ 所有图标必须有data-content（可编辑图标本身）
- ✅ 所有文字必须有data-content（可编辑文字内容）
- ✅ 所有图片必须有data-content（可编辑、替换图片）

### 3. 事件冒泡处理规则
```javascript
// 点击容器内图标 → 编辑图标
// 点击容器空白处 → 编辑容器属性（不触发图标编辑）
if (e.target.hasAttribute('data-content')) {
    blockElement = e.target; // 优先直接点击的元素
} else if (containerElement.includes('icon-container')) {
    const clickedIcon = e.target.closest('.material-symbols-outlined, img[data-content]');
    blockElement = clickedIcon || containerElement;
}
```

### 4. 图片编辑功能
- ✅ 支持编辑图片alt属性
- ✅ 支持编辑图片src路径
- ✅ 支持从外部导入图片
- ✅ 支持实时预览修改后的图片

## 块命名规范

| 类型 | 命名格式 | 示例 |
|------|---------|------|
| 容器 | `{page}-icon-container-{n}` | `products-icon-container-1` |
| 图标 | `icon-{name}` | `icon-category`, `icon-health` |
| 标签文字 | `label-{name}` | `label-product-lineup` |
| 图片 | `img-{filename}` | `img-owl_monitor`, `img-radar` |
| 表单 | `form-{field}` | `form-label`, `form-input-name` |

## 检查清单

每次块细分后必须验证：
- [ ] 所有容器都有data-content
- [ ] 所有图标都有data-content
- [ ] 所有文字都有data-content
- [ ] 所有图片都有data-content
- [ ] 点击容器不会误触发图标编辑
- [ ] 容器和图标都可以独立编辑
- [ ] 没有遗漏的大块

## 统计标准

- 目标：每个可视元素都应该是独立的块
- products.html: 200+ 块（产品详情页，内容最多）
- index.html: 90+ 块（首页）
- contact.html: 50+ 块（联系页）
- partnership.html: 85+ 块（合作页）
- privacy-policy.html: 65+ 块（隐私政策）
- terms-of-service.html: 55+ 块（服务条款）
- **总计：564+ 块**

## 禁止的做法

❌ 删除容器的data-content来避免冲突
❌ 使用`closest('[data-content]')`简单查找最近的块
❌ 忽略文字、图片等"小元素"
❌ 认为"差不多就行"
❌ 用临时方案绕过问题

## 必须的做法

✅ 修复事件处理逻辑
✅ 细分到最小可编辑单元
✅ 运行Python脚本验证
✅ 手动测试容器和图标的点击行为
✅ 统计块数量确保没有遗漏
