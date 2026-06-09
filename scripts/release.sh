#!/bin/bash
# release.sh - 自动化发布脚本
# 用法: ./scripts/release.sh 1.0.9

set -e

VERSION=$1
PLUGIN_NAME="claude-idle-alert"
PLUGIN_JSON=".claude-plugin/plugin.json"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 错误处理
error() {
  echo -e "${RED}❌ 错误: $1${NC}" >&2
  exit 1
}

success() {
  echo -e "${GREEN}✅ $1${NC}"
}

info() {
  echo -e "${YELLOW}ℹ️  $1${NC}"
}

# 验证输入
if [ -z "$VERSION" ]; then
  error "使用方法: ./scripts/release.sh <版本号>\n示例: ./scripts/release.sh 1.0.9"
fi

# 验证版本号格式 (x.y.z)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  error "版本号格式错误: $VERSION。应为 x.y.z 格式 (如 1.0.9)"
fi

info "发布版本: $VERSION"
echo ""

# 检查 git 状态
info "检查 git 状态..."
if [ -n "$(git status --porcelain)" ]; then
  error "工作目录有未提交的改动。请先提交或stash:\n$(git status --short)"
fi
success "工作目录干净"

# 检查分支
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
  error "当前分支是 $CURRENT_BRANCH，应该在 main 分支发布"
fi
success "正在 main 分支"

# 检查 plugin.json 存在
if [ ! -f "$PLUGIN_JSON" ]; then
  error "找不到 $PLUGIN_JSON"
fi

# 提取当前版本
CURRENT_VERSION=$(grep '"version"' "$PLUGIN_JSON" | head -1 | cut -d'"' -f4)
info "当前版本: $CURRENT_VERSION → $VERSION"

# 验证版本号递增
if [ "$VERSION" == "$CURRENT_VERSION" ]; then
  error "版本号未改变，仍为 $CURRENT_VERSION"
fi
success "版本号有效"
echo ""

# 询问确认
echo "准备发布:"
echo "  当前分支: main"
echo "  版本号: $CURRENT_VERSION → $VERSION"
echo ""
read -p "确认发布? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  error "发布已取消"
fi
echo ""

# 更新版本号
info "更新版本号..."
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" "$PLUGIN_JSON"
success "版本号已更新: $VERSION"

# 提交到 git
info "提交到 git..."
git add "$PLUGIN_JSON"
git commit -m "chore: bump version to $VERSION"
success "已提交到 main"

# 同步到 zh 分支
info "同步到 zh 分支..."
git checkout zh
git cherry-pick main
git checkout main
success "已同步到 zh 分支"

# 推送到远程
info "推送到 GitHub..."
git push origin main
git push origin zh
success "已推送到 GitHub"
echo ""

# 卸载旧插件
info "卸载旧版本插件..."
claude plugin uninstall "$PLUGIN_NAME" 2>/dev/null || true
sleep 1
success "已卸载"

# 删除缓存
info "清除旧缓存..."
CACHE_DIR="$HOME/.claude/plugins/cache/$PLUGIN_NAME"
if [ -d "$CACHE_DIR" ]; then
  rm -rf "$CACHE_DIR"
  success "缓存已清除"
else
  info "缓存目录不存在（首次安装）"
fi

# 更新 marketplace
info "更新 marketplace..."
claude plugin marketplace update "$PLUGIN_NAME"
success "marketplace 已更新"

# 安装新版本
info "安装新版本..."
claude plugin install "$PLUGIN_NAME"
success "新版本已安装"
echo ""

# 验证版本一致性
info "验证版本一致性..."
sleep 2

CACHE_VERSIONS=$(ls "$HOME/.claude/plugins/cache/$PLUGIN_NAME/$PLUGIN_NAME/" 2>/dev/null | tail -1)
if [ -z "$CACHE_VERSIONS" ]; then
  error "无法验证缓存版本（缓存目录为空）"
fi

if [ "$VERSION" == "$CACHE_VERSIONS" ]; then
  success "版本一致: $VERSION"
else
  error "版本不一致！源代码=$VERSION，缓存=$CACHE_VERSIONS"
fi
echo ""

# 最终总结
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ 发布完成！${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "发布摘要:"
echo "  版本号: $VERSION"
echo "  GitHub: 已推送到 main 和 zh 分支"
echo "  插件: 已安装到本地"
echo "  缓存: $CACHE_DIR/$PLUGIN_NAME/$VERSION"
echo ""
echo "下一步:"
echo "  1. 在 Claude Code 中执行 Reload Window"
echo "  2. 运行 /idle-alert 来验证新功能"
echo ""
