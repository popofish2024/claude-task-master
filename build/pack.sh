#!/bin/bash

# Task Master 快速打包脚本
# 用法: ./scripts/pack.sh [选项]
# 选项:
#   --test     运行测试
#   --clean    清理旧包
#   --install  打包后自动安装

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"

# 解析命令行参数
RUN_TESTS=false
CLEAN_OLD=false
AUTO_INSTALL=false

for arg in "$@"; do
    case $arg in
        --test)
            RUN_TESTS=true
            shift
            ;;
        --clean)
            CLEAN_OLD=true
            shift
            ;;
        --install)
            AUTO_INSTALL=true
            shift
            ;;
        --help|-h)
            echo "Task Master 打包脚本"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --test      运行测试"
            echo "  --clean     清理旧包"
            echo "  --install   打包后自动安装"
            echo "  --help, -h  显示帮助信息"
            exit 0
            ;;
        *)
            log_warn "未知参数: $arg"
            ;;
    esac
done

# 进入项目根目录
cd "$PROJECT_ROOT"

echo -e "${CYAN}🚀 Task Master 快速打包工具${NC}\n"

# 读取package.json信息
PACKAGE_NAME=$(node -p "require('./package.json').name")
PACKAGE_VERSION=$(node -p "require('./package.json').version")

log_info "准备打包 $PACKAGE_NAME v$PACKAGE_VERSION"

# 清理旧包
if [ "$CLEAN_OLD" = true ]; then
    log_info "清理旧包文件..."
    rm -f *.tgz
    rm -rf "$DIST_DIR"
    mkdir -p "$DIST_DIR"
    log_success "清理完成"
fi

# 创建.npmignore文件
log_info "创建 .npmignore 文件..."
cat > .npmignore << 'EOF'
# 开发相关文件
.git/
.github/
.vscode/
.idea/
*.swp
*.swo
*~

# 测试文件
tests/
test/
*.test.js
*.spec.js
coverage/
.nyc_output/
junit.xml

# 构建和临时文件
dist/
build/
tmp/
temp/
.temp/
*.tmp
*.temp
.cache/
.parcel-cache/

# 日志文件
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# 依赖目录
node_modules/

# 环境变量文件
.env
.env.*
!.env.example

# 配置文件
.eslintrc*
.prettierrc*
.editorconfig
biome.json
jest.config.js
.babelrc*
tsconfig.json

# 文档和示例（保留主要README）
docs/
examples/
*.md
!README.md
!README-task-master.md

# Task Master 特定文件
tasks/
_task-master-mcp_logs.txt
.taskmasterconfig.backup
.taskmasterconfig
scripts/task-complexity-report.json

# 开发脚本
scripts/build-package.js
scripts/pack.sh
scripts/test-*.js
scripts/dev.js

# 版本控制
.changeset/
CHANGELOG.md

# 其他
.DS_Store
Thumbs.db
*.tgz
EOF

log_success "创建 .npmignore 文件完成"

# 检查和修复文件权限
log_info "检查文件权限..."
chmod +x bin/task-master.js
chmod +x mcp-server/server.js
log_success "文件权限检查完成"

# 运行测试（可选）
if [ "$RUN_TESTS" = true ]; then
    log_info "运行测试..."
    if npm test; then
        log_success "测试通过"
    else
        log_error "测试失败"
        exit 1
    fi
fi

# 创建包
log_info "开始打包..."
PACKAGE_FILE=$(npm pack | tail -1 | tr -d '\n\r')

if [ -z "$PACKAGE_FILE" ]; then
    log_error "打包失败：npm pack 没有返回文件名"
    exit 1
fi

# 检查包文件是否存在
if [ ! -f "$PACKAGE_FILE" ]; then
    log_error "包文件不存在: $PACKAGE_FILE"
    exit 1
fi

# 移动包到dist目录
if [ ! -d "$DIST_DIR" ]; then
    mkdir -p "$DIST_DIR"
fi

mv "$PACKAGE_FILE" "$DIST_DIR/"
PACKAGE_PATH="$DIST_DIR/$PACKAGE_FILE"

# 创建latest版本副本
LATEST_FILE="${PACKAGE_NAME}-latest.tgz"
LATEST_PATH="$DIST_DIR/$LATEST_FILE"
cp "$PACKAGE_PATH" "$LATEST_PATH"
log_success "创建latest版本: $LATEST_FILE"

# 获取包大小
PACKAGE_SIZE=$(du -h "$PACKAGE_PATH" | cut -f1)
LATEST_SIZE=$(du -h "$LATEST_PATH" | cut -f1)

# 显示结果
echo ""
log_success "📦 打包完成!"
echo ""
echo -e "${CYAN}包信息:${NC}"
echo "  名称: $PACKAGE_NAME"
echo "  版本: $PACKAGE_VERSION"
echo "  主文件: $PACKAGE_FILE ($PACKAGE_SIZE)"
echo "  主路径: $PACKAGE_PATH"
echo "  Latest文件: $LATEST_FILE ($LATEST_SIZE)"
echo "  Latest路径: $LATEST_PATH"
echo ""
echo -e "${CYAN}安装方法:${NC}"
echo -e "  ${GREEN}npm install -g${NC} $PACKAGE_PATH"
echo -e "  ${GREEN}npm install${NC} $PACKAGE_PATH"
echo ""
echo -e "${CYAN}验证安装:${NC}"
echo -e "  ${GREEN}task-master --version${NC}"
echo -e "  ${GREEN}task-master --help${NC}"

# 自动安装（可选）
if [ "$AUTO_INSTALL" = true ]; then
    echo ""
    log_info "自动安装包..."
    if npm install -g "$PACKAGE_PATH"; then
        log_success "安装完成"
        echo ""
        log_info "验证安装..."
        task-master --version
    else
        log_error "安装失败"
        exit 1
    fi
fi

echo ""
log_success "🎉 所有操作完成!"
