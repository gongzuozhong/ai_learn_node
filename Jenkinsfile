pipeline {
    agent any
    environment {
        HOST_IP = '192.168.10.168' //宿主机内网 IP（容器可访问）
        HOST_USER = 'root'          // 宿主机用户名
        SSH_KEY_PATH = '/var/jenkins_home/.ssh/id_rsa'
        HOST_TARGET = '/www/wwwroot/gitadmin.localgitserver.com/'  // 宿主机目标目录
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
                        # 1. 检查SSH密钥文件是否存在
                        if [ ! -f "${SSH_KEY_PATH}" ]; then
                            echo "❌ 错误: SSH密钥文件不存在: ${SSH_KEY_PATH}"
                            exit 1
                        fi
                        
                        # 2. 设置密钥权限（确保只有所有者可读）
                        chmod 600 ${SSH_KEY_PATH}
                        
                        # 3. 宿主机创建备份目录
                        ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} "mkdir -p ${HOST_BACKUP}"
                        
                        # 4. 宿主机备份原有部署目录（如有）
                        ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} "
                            if [ -d '${HOST_TARGET}' ]; then
                                TIMESTAMP=$(date +%Y%m%d%H%M%S)
                                mv '${HOST_TARGET}' '${HOST_BACKUP}/backup_$TIMESTAMP'
                            fi
                        "
                        
                        # 5. SCP传输构建产物到宿主机（注意：scp命令的-i参数位置）
                        scp -i ${SSH_KEY_PATH} -r -o StrictHostKeyChecking=no build-output/* ${HOST_USER}@${HOST_IP}:${HOST_TARGET}/
                        
                        # 6. 宿主机修复目录权限
                        ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} "chmod -R 755 ${HOST_TARGET}"
                        
                        # 7. 安装后端生产依赖
                        echo "安装后端生产依赖..."
                        ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} "
                            cd ${HOST_TARGET}/backend
                            #npm install --production
                        "
                        
                        # 8. 配置目录权限
                        ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} "
                            chmod -R 755 ${HOST_TARGET}
                            if id -u www >/dev/null 2>&1; then
                                chown -R www:www ${HOST_TARGET}
                            fi
                        "
                        
                        echo "✅ 部署完成！"
                        echo "前端访问地址: http://192.168.10.168/aistudy"
                        echo "后端服务目录: ${HOST_TARGET}/backend"
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
