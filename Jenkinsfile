pipeline {
    agent any
    environment {
        // 本地 Web 部署目录（根据实际环境修改，需确保 Jenkins 有读写权限）
        LOCAL_WEB_ROOT = '/www/wwwroot/gitadmin.localgitserver.com'
        // 项目部署子目录（避免与其他项目冲突）
        PROJECT_DEPLOY_DIR = "${LOCAL_WEB_ROOT}/aistudy"
        // 备份目录（保留历史版本，便于回滚）
        BACKUP_DIR = "${LOCAL_WEB_ROOT}/aistudy-backups"
    }
    // 定义工具（Node.js 需在 Jenkins 全局工具配置中提前配置）
    tools {
        nodejs 'NodeJS-22' // 替换为你的 Jenkins Node.js 工具名称（无则注释此行）
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '检出代码...'
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                echo '构建项目...'
                sh '''
                    # 验证 Node.js 环境
                    if ! command -v node >/dev/null 2>&1; then
                        echo "❌ 错误: 未找到 Node.js 命令"
                        echo "请确保 Jenkins 节点已安装 Node.js 并配置到环境变量"
                        exit 1
                    fi
                    echo "Node 版本: $(node --version)"
                    echo "NPM 版本: $(npm --version)"
                    
                    # 安装项目依赖
                    echo "安装依赖..."
                    npm install
                    npm run install:all
                    
                    # 构建前端（生成静态资源）
                    echo "构建前端..."
                    npm run build --workspace=frontend
                    
                    # 构建后端（TypeScript 编译 + Prisma Client 生成）
                    echo "构建后端..."
                    cd backend
                    npm run prisma:generate
                    npm run build
                    cd ..
                '''
            }
        }
        
        stage('Prepare Deployment Files') {
            steps {
                echo '准备部署文件...'
                sh '''
                    # 创建临时构建目录（整理部署所需文件）
                    mkdir -p build-output/frontend
                    mkdir -p build-output/backend
                    chmod -R 755 build-output  # 确保Jenkins用户有读写权限
                    
                    # 复制前端构建产物（静态资源，直接部署到 Web 根目录）
                    cp -r frontend/dist/* build-output/frontend/
                    
                    # 复制后端运行文件（编译后的代码 + 依赖配置 + Prisma）
                    cp -r backend/dist build-output/backend/
                    cp -r backend/prisma build-output/backend/
                    cp backend/package.json build-output/backend/
                    cp backend/package-lock.json build-output/backend/
                   
                '''
            }
        }
        
        stage('Deploy to Local Web Server') {
            steps {
                echo "部署到本地 Web 目录: ${PROJECT_DEPLOY_DIR}"
                sh '''
                    # 创建备份目录（若不存在）
                    mkdir -p ${BACKUP_DIR}
                    
                    # 备份当前运行版本（保留时间戳，便于回滚）
                    if [ -d ${PROJECT_DEPLOY_DIR} ]; then
                        BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
                        mv ${PROJECT_DEPLOY_DIR} ${BACKUP_DIR}/${BACKUP_NAME}
                        echo "✅ 已备份当前版本到: ${BACKUP_DIR}/${BACKUP_NAME}"
                    fi
                    
                    # 创建新的部署目录
                    mkdir -p ${PROJECT_DEPLOY_DIR}
                    
                    # 复制前端静态资源到 Web 可访问目录
                    cp -r build-output/frontend/* ${PROJECT_DEPLOY_DIR}/
                    
                    # 复制后端文件到部署目录（后端可通过 Node 服务运行）
                    mkdir -p ${PROJECT_DEPLOY_DIR}/backend
                    cp -r build-output/backend/* ${PROJECT_DEPLOY_DIR}/backend/
                    
                    
                    
                    # 安装后端生产依赖（避免复制 node_modules，减少体积）
                    echo "安装后端生产依赖..."
                    cd ${PROJECT_DEPLOY_DIR}/backend
                    npm install --production
                    
                    # 启动/重启后端服务（根据项目实际启动方式调整）
                    echo "启动后端服务..."
                    # 方式1：直接通过 node 启动（前台运行，适合简单场景）
                    # nohup node dist/index.js > ${PROJECT_DEPLOY_DIR}/backend.log 2>&1 &
                    

                    
                    # 配置目录权限（确保 Web 服务器和 Node 服务可访问）
                    chmod -R 755 ${PROJECT_DEPLOY_DIR}
                    # 若 Web 服务器用户为 www（如 Nginx/Apache），添加权限
                    if id -u www >/dev/null 2>&1; then
                        chown -R www:www ${PROJECT_DEPLOY_DIR}
                    fi
                    
                    echo "✅ 部署完成！"
                    echo "前端访问地址: http://192.168.10.168/aistudy"
                    echo "后端服务目录: ${PROJECT_DEPLOY_DIR}/backend"
                '''
            }
        }
    }
    
    post {
        success {
            echo '🎉 本地部署成功！'
            echo "📁 部署目录: ${PROJECT_DEPLOY_DIR}"
            echo "💾 备份目录: ${BACKUP_DIR}"
        }
        failure {
            echo '❌ 部署失败！请查看构建日志排查问题'
        }
        always {
            // 清理构建临时文件
            sh 'rm -rf build-output node_modules frontend/node_modules backend/node_modules'
        }
    }
}
