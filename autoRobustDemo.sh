#!/bin/bash

# autoRobust.sh - Android应用构建和Robust补丁管理脚本
# 使用方法: ./autoRobust.sh [patch|build]

set -e  # 遇到错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "AutoRobust构建脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 <mode>"
    echo ""
    echo "参数:"
    echo "  mode    构建模式，支持以下值:"
    echo "          build  - 构建APK并安装到设备 (不生成补丁)"
    echo "          patch  - 构建并生成补丁文件，然后推送到设备 (不安装APK)"
    echo ""
    echo "构建命令:"
    echo "  build模式: ./gradlew :app:clean :app:assembleRelease -DautoRobust.buildPatch=false"
    echo "  patch模式: ./gradlew :app:clean :app:assembleRelease -DautoRobust.buildPatch=true"
    echo ""
    echo "示例:"
    echo "  $0 build   # 构建并安装APK"
    echo "  $0 patch   # 生成补丁并推送到设备"
    echo ""
}

# 检查参数
check_parameters() {
    if [ $# -eq 0 ]; then
        log_error "缺少必需参数"
        show_help
        exit 1
    fi

    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi

    MODE="$1"

    if [ "$MODE" != "build" ] && [ "$MODE" != "patch" ]; then
        log_error "无效的模式: $MODE"
        log_error "支持的模式: build, patch"
        show_help
        exit 1
    fi
}

# 检查必需的工具
check_requirements() {
    log_info "检查必需工具..."

    # 检查gradlew
    if [ ! -f "./gradlew" ]; then
        log_error "gradlew文件不存在，请确保在Android项目根目录下运行此脚本"
        exit 1
    fi

    # 检查adb (仅在需要设备操作时)
    if [ "$MODE" = "build" ] || [ "$MODE" = "patch" ]; then
        if ! command -v adb &> /dev/null; then
            log_error "adb命令未找到，请确保Android SDK已正确安装并配置PATH"
            exit 1
        fi
    fi

    log_success "工具检查完成"
}

# 检查设备连接
check_device() {
    log_info "检查设备连接..."

    # 检查是否有设备连接
    DEVICE_COUNT=$(adb devices | grep -v "List of devices" | grep -c "device$" || true)

    if [ "$DEVICE_COUNT" -eq 0 ]; then
        log_error "未检测到连接的Android设备"
        log_error "请确保设备已连接并开启USB调试"
        exit 1
    elif [ "$DEVICE_COUNT" -gt 1 ]; then
        log_warning "检测到多个设备，将使用第一个设备"
        adb devices
    fi

    log_success "设备连接正常"
}

# 获取当前工程目录
get_project_dir() {
    PROJECT_DIR=$(pwd)
    log_info "项目目录: $PROJECT_DIR"
}

# 执行Gradle构建
build_project() {
    log_info "开始构建项目..."

    # 根据模式设置不同的构建命令
    case $MODE in
        "build")
            GRADLE_CMD="./gradlew :app:clean :app:assembleRelease -DautoRobust.buildPatch=false"
            log_info "Build模式 - 构建APK，不生成补丁"
            ;;
        "patch")
            GRADLE_CMD="./gradlew :app:clean :app:assembleRelease -DautoRobust.buildPatch=true"
            log_info "Patch模式 - 构建APK并生成补丁"
            ;;
        *)
            log_error "未知的构建模式: $MODE"
            exit 1
            ;;
    esac

    log_info "执行命令: $GRADLE_CMD"

    # 给gradlew执行权限
    chmod +x ./gradlew

    # 显示构建开始时间
    BUILD_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    log_info "构建开始时间: $BUILD_START_TIME"

    # 初始化构建状态变量
    BUILD_SUCCESS=false
    BUILD_EXIT_CODE=0

    # 根据模式使用不同的错误处理策略
    if [ "$MODE" = "build" ]; then
        # Build模式：严格错误处理，构建失败则退出
        log_info "Build模式 - 严格错误处理模式"

        if eval "$GRADLE_CMD"; then
            BUILD_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
            log_success "项目构建完成"
            log_info "构建结束时间: $BUILD_END_TIME"
            BUILD_SUCCESS=true
        else
            BUILD_EXIT_CODE=$?
            BUILD_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
            log_error "项目构建失败（退出码: $BUILD_EXIT_CODE）"
            log_error "构建结束时间: $BUILD_END_TIME"
            log_error "请检查构建日志以获取详细错误信息"
            log_error "Build模式要求构建成功才能继续执行"
            exit 1
        fi

    elif [ "$MODE" = "patch" ]; then
        # Patch模式：宽松错误处理，构建失败时记录警告但继续执行
        log_info "Patch模式 - 容错处理模式"
        log_info "注意: 即使构建失败也会尝试继续执行"

        # 临时禁用错误自动退出
        set +e
        eval "$GRADLE_CMD"
        BUILD_EXIT_CODE=$?
        # 重新启用错误自动退出
        set -e

        BUILD_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        log_info "构建结束时间: $BUILD_END_TIME"

        if [ $BUILD_EXIT_CODE -eq 0 ]; then
            log_success "项目构建完成"
            BUILD_SUCCESS=true
        else
            log_warning "项目构建遇到问题（退出码: $BUILD_EXIT_CODE）"
            log_warning "但将继续执行后续步骤，尝试查找已有的补丁文件"
            log_info "可能的情况:"
            log_info "1. 补丁文件可能已在之前的构建中生成"
            log_info "2. 部分构建任务成功，补丁生成任务可能已完成"
            log_info "3. 如果找不到补丁文件，脚本将在后续步骤中报错"
            BUILD_SUCCESS=false
        fi
    fi

    # 记录构建状态供后续步骤使用
    export BUILD_SUCCESS
    export BUILD_EXIT_CODE
}

# Build模式 - 检查并安装APK
process_build_mode() {
    log_info "=== Build模式处理流程 ==="
    log_info "检查APK文件并安装到设备"

    # APK文件路径
    APK_PATH="$PROJECT_DIR/app/build/outputs/apk/release/app-release.apk"

    # 检查APK文件是否存在
    if [ ! -f "$APK_PATH" ]; then
        log_error "APK文件不存在: $APK_PATH"
        log_error "请检查构建是否成功"

        # 尝试查找其他可能的APK路径
        log_info "尝试查找其他APK文件..."
        FOUND_APKS=$(find "$PROJECT_DIR/app/build/outputs/apk" -name "*.apk" -type f 2>/dev/null || true)
        if [ -n "$FOUND_APKS" ]; then
            log_info "找到的APK文件:"
            echo "$FOUND_APKS"
        else
            log_error "未找到任何APK文件"
        fi

        exit 1
    fi

    # 显示APK文件信息
    APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
    log_success "APK文件检查通过"
    log_info "APK文件: $APK_PATH"
    log_info "APK大小: $APK_SIZE"

    # 检查设备连接
    check_device

    # 安装APK
    log_info "开始安装APK..."
    log_info "执行命令: adb install -r -t -d $APK_PATH"

    if adb install -r -t -d "$APK_PATH"; then
        log_success "APK安装成功"
    else
        log_error "APK安装失败"
        log_error "可能的原因:"
        log_error "1. 设备存储空间不足"
        log_error "2. 应用签名冲突"
        log_error "3. 设备权限限制"
        exit 1
    fi
}

# Patch模式 - 检查并推送补丁文件
process_patch_mode() {
    log_info "=== Patch模式处理流程 ==="
    log_info "检查补丁文件并推送到设备"

    # 补丁文件路径
    PATCH_PATH="$PROJECT_DIR/app/build/outputs/robust/patch.jar"

    # 检查补丁文件是否存在
    if [ ! -f "$PATCH_PATH" ]; then
        log_error "补丁文件不存在: $PATCH_PATH"
        log_error "请检查Robust补丁是否正确生成"

        # 尝试查找其他可能的补丁文件
        log_info "尝试查找其他补丁文件..."
        FOUND_PATCHES=$(find "$PROJECT_DIR/app/build/outputs" -name "*.jar" -type f 2>/dev/null || true)
        if [ -n "$FOUND_PATCHES" ]; then
            log_info "找到的JAR文件:"
            echo "$FOUND_PATCHES"
        else
            log_error "未找到任何JAR文件"
        fi

        exit 1
    fi

    # 显示补丁文件信息
    PATCH_SIZE=$(ls -lh "$PATCH_PATH" | awk '{print $5}')
    log_success "补丁文件检查通过"
    log_info "补丁文件: $PATCH_PATH"
    log_info "补丁大小: $PATCH_SIZE"

    # 检查设备连接
    check_device

    # 推送补丁文件
    log_info "开始推送补丁文件..."

    # 目标路径
    TARGET_PATH="/sdcard/Android/data/com.meituan.robust.sample/files/robust"
    log_info "目标路径: $TARGET_PATH"

    # 创建目标目录（如果不存在）
    log_info "创建目标目录..."
    adb shell "mkdir -p $TARGET_PATH" 2>/dev/null || true

    # 推送补丁文件
    log_info "执行命令: adb push $PATCH_PATH $TARGET_PATH/"

    if adb push "$PATCH_PATH" "$TARGET_PATH/"; then
        log_success "补丁文件推送成功"

        # 验证文件是否推送成功
        log_info "验证文件推送..."
        if adb shell "ls -la $TARGET_PATH/patch.jar" 2>/dev/null; then
            log_success "补丁文件验证成功"

            # 显示设备上的文件信息
            DEVICE_FILE_INFO=$(adb shell "ls -la $TARGET_PATH/patch.jar" 2>/dev/null)
            log_info "设备上的文件信息: $DEVICE_FILE_INFO"
        else
            log_warning "补丁文件验证失败，但推送命令返回成功"
        fi
    else
        log_error "补丁文件推送失败"
        log_error "可能的原因:"
        log_error "1. 设备存储权限限制"
        log_error "2. 目标目录不存在或无权限"
        log_error "3. 设备存储空间不足"
        exit 1
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    log_success "=== AutoRobust脚本执行完成 ==="
    case $MODE in
        "build")
            log_success "模式: Build - 构建并安装APK"
            log_info "✅ APK已成功安装到设备"
            log_info "✅ 此版本为基准版本，用于后续补丁对比"
            log_info "📱 可以启动应用进行测试"
            ;;
        "patch")
            log_success "模式: Patch - 生成并推送补丁"
            log_info "✅ 补丁文件已成功推送到设备"
            log_info "📍 补丁路径: /sdcard/Android/data/com.meituan.robust.sample/files/robust/patch.jar"
            log_info "🔄 重启应用以加载补丁文件"
            log_info "💡 提示: 无需重新安装APK，补丁会自动生效"
            ;;
    esac
    echo ""
}

# 清理函数
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "脚本执行失败"
        log_info "请检查上述错误信息并重试"
    fi
}

# 主函数
main() {
    log_info "=== AutoRobust构建脚本启动 ==="

    # 检查参数
    check_parameters "$@"

    log_info "执行模式: $MODE"

    # 设置错误处理
    if [ "$MODE" == "build" ]; then
      trap cleanup EXIT
    fi

    # 检查必需工具
    check_requirements

    # 获取项目目录
    get_project_dir

    # 执行构建
    build_project

    # 根据模式执行相应操作
    case $MODE in
        "build")
            process_build_mode
            ;;
        "patch")
            process_patch_mode
            ;;
        *)
            log_error "未知模式: $MODE"
            exit 1
            ;;
    esac

    # 显示完成信息
    show_completion
}

# 脚本入口
main "$@"