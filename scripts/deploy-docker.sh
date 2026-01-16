#!/bin/bash

# Docker/Podman 部署脚本 - 在远程服务器上执行
# 用法: ./deploy-docker.sh <部署目录>

set -e

DEPLOY_DIR=${1:-/opt/nginx/html/ai/current}
DOCKER_DIR="$DEPLOY_DIR/docker"

echo "开始容器部署到: $DEPLOY_DIR"

# 检查部署目录是否存在
if [ ! -d "$DEPLOY_DIR" ]; then
    echo "错误: 部署目录不存在: $DEPLOY_DIR"
    exit 1
fi

# 检测容器运行时（优先使用 Podman，然后是 Docker）
CONTAINER_CMD=""
COMPOSE_CMD=""

if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    echo "检测到 Podman"
    
    # 检查 podman-compose 或 podman compose
    if command -v podman-compose &> /dev/null; then
        COMPOSE_CMD="podman-compose"
    elif podman compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="podman compose"
    else
        echo "错误: podman-compose 未安装"
        echo "提示: 请安装 podman-compose 或 podman-compose 插件"
        echo "安装方法: pip install podman-compose 或 dnf install podman-compose"
        exit 1
    fi
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
    echo "检测到 Docker"
    
    # 检查 docker-compose 或 docker compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        echo "错误: docker-compose 未安装"
        echo "提示: 请安装 docker-compose 或确保 Docker 版本 >= 20.10"
        exit 1
    fi
else
    echo "错误: 未找到 Podman 或 Docker"
    exit 1
fi

echo "使用容器命令: $CONTAINER_CMD"
echo "使用 Compose 命令: $COMPOSE_CMD"

# 进入 Docker 目录
if [ ! -d "$DOCKER_DIR" ]; then
    echo "错误: Docker 配置目录不存在: $DOCKER_DIR"
    exit 1
fi

cd "$DOCKER_DIR" || exit 1

# 确定 compose 文件路径（podman-compose 默认查找 docker-compose.yml）
COMPOSE_FILE="docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    # 如果不存在，尝试其他可能的文件名
    if [ -f "docker-compose.production.yml" ]; then
        COMPOSE_FILE="docker-compose.production.yml"
    elif [ -f "compose.yml" ]; then
        COMPOSE_FILE="compose.yml"
    else
        echo "错误: 未找到 docker-compose.yml 文件"
        echo "当前目录: $(pwd)"
        echo "文件列表:"
        ls -la || true
        exit 1
    fi
fi

echo "使用 Compose 文件: $COMPOSE_FILE"

# 停止旧容器（如果存在）
echo "停止旧容器..."
if [ "$COMPOSE_FILE" = "docker-compose.yml" ]; then
    $COMPOSE_CMD down || true
else
    $COMPOSE_CMD -f "$COMPOSE_FILE" down || true
fi

# 构建并启动服务
echo "构建并启动容器服务..."
if [ "$COMPOSE_FILE" = "docker-compose.yml" ]; then
    $COMPOSE_CMD up -d --build
else
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d --build
fi

# 等待服务启动
echo "等待服务启动..."
sleep 5

# 检查服务状态
echo "检查服务状态..."
$COMPOSE_CMD ps

# 检查容器健康状态
echo "检查容器健康状态..."
if $CONTAINER_CMD ps | grep -q ai-learning-nginx; then
    echo "✅ Nginx 容器运行中"
else
    echo "❌ Nginx 容器未运行"
    exit 1
fi

if $CONTAINER_CMD ps | grep -q ai-learning-backend; then
    echo "✅ Backend 容器运行中"
else
    echo "❌ Backend 容器未运行"
    exit 1
fi

echo ""
echo "=========================================="
echo "容器部署完成！"
echo "=========================================="
echo "前端访问: http://180.76.180.105:8080"
echo "后端 API: http://180.76.180.105:3001"
echo "健康检查: http://180.76.180.105:8080/health"
echo "=========================================="
