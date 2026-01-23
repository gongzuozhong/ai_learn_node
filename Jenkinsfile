pipeline {
    agent any
    environment {
        HOST_IP = '192.168.10.168' //宿主机内网 IP（容器可访问）
        HOST_USER = ''          // 宿主机用户名
        HOST_PASS = '' //宿主机密码（生产环境用密钥更安全）
        HOST_TARGET = '/www/wwwroot/gitadmin.localgitserver.com/aistudy'  // 宿主机目标目录
        HOST_BACKUP = '/www/wwwroot/gitadmin.localgitserver.com/aistudy-backups'  //宿主机备份目录
    }
    // 定义工具（Node.js 需在 Jenkins 全局工具配置中提前配置）
    tools {
        nodejs 'NodeJS-22' // 替换为你的 Jenkins Node.js 工具名称（无则注释此行）
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "===============================检出代码...========================================"
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                echo '===============================构建项目...==============================='
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
                    echo "===============================构建前端...==============================="
                    npm run build --workspace=frontend
                    
                    # 构建后端（TypeScript 编译 + Prisma Client 生成）
                    echo "===============================构建后端...==============================="
                    cd backend
                    npm run prisma:generate
                    npm run build
                    cd ..
                '''
            }
        }
        
        stage('Prepare Deployment Files') {
            steps {
                echo '===============================准备部署文件...==============================='
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
                    #    cp backend/package-lock.json build-output/backend/
                   
                '''
            }
        }
        
        stage('Deploy via SSH') {
            steps {
                withEnv([]) {
                    echo "通过 SSH 部署到宿主机: ${HOST_TARGET}"
                    sh '''
                        # 1. 宿主机创建备份目录（通过 SSH 执行宿主机命令）
                        sshpass -p "${HOST_PASS}" ssh -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} "mkdir -p ${HOST_BACKUP}"
                        
                        # 2. 宿主机备份原有部署目录（如有）
                        sshpass -p "${HOST_PASS}" ssh -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} "
                            if [ -d '${HOST_TARGET}' ]; then
                                TIMESTAMP=$(date +%Y%m%d%H%M%S)
                                mv '${HOST_TARGET}' '${HOST_BACKUP}/backup_$TIMESTAMP'
                            fi
                        "
                        
                        # 3. SCP 传输构建产物到宿主机
                        sshpass -p "${HOST_PASS}" scp -r -o StrictHostKeyChecking=no build-output/* ${HOST_USER}@${HOST_IP}:${HOST_TARGET}/
                        
                        # 4. 宿主机修复目录权限（确保 Web 服务可访问）
                        sshpass -p "${HOST_PASS}" ssh -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} "chmod -R 755 ${HOST_TARGET}"

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
    }
    post {
        success {
            echo '🎉 本地部署成功！'
            echo "📁 部署目录: ${HOST_TARGET}"
            echo "💾 备份目录: ${HOST_BACKUP}"
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
