pipeline {
    agent any

    environment {
        // 远程服务器配置
        DEPLOY_HOST = '180.76.180.105'
        DEPLOY_USER = 'root'  // 根据实际情况修改用户名
        DEPLOY_PATH = '/opt/nginx/html/ai'
        // 如果需要 SSH 密钥，可以在 Jenkins 中配置 SSH credentials
        // SSH_CREDENTIALS = credentials('deploy-ssh-key')
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
                    # 使用全局配置的 Node.js 路径
                    JENKINS_NODE_PATH="/var/jenkins_home/tools/jenkins.plugins.nodejs.tools.NodeJSInstallation/NodeJS-22/bin"
                    
                    if [ -f "$JENKINS_NODE_PATH/node" ]; then
                        echo "✅ 使用全局配置的 Node.js: $JENKINS_NODE_PATH"
                        export PATH="$JENKINS_NODE_PATH:$PATH"
                    else
                        echo "❌ 错误: Node.js 未找到，请检查全局工具配置"
                        exit 1
                    fi
                    
                    echo "Node 版本: $(node --version)"
                    echo "NPM 版本: $(npm --version)"
                    echo "Node 路径: $(which node)"
                    
                    # 安装依赖
                    echo "安装依赖..."
                    npm install
                    npm run install:all
                    
                    # 构建前端
                    echo "构建前端..."
                    npm run build --workspace=frontend
                    
                    # 构建后端
                    echo "构建后端..."
                    cd backend
                    # 先生成 Prisma Client（构建时需要类型）
                    npm run prisma:generate
                    # 然后构建 TypeScript
                    npm run build
                    cd ..
                '''
            }
        }
        
        stage('Prepare Deployment Package') {
            steps {
                echo '准备部署包...'
                sh '''
                    # 创建临时部署目录
                    mkdir -p deploy-package
                    
                    # 复制前端构建产物
                    cp -r frontend/dist deploy-package/frontend-dist
                    
                    # 复制后端文件
                    mkdir -p deploy-package/backend
                    cp -r backend/dist deploy-package/backend/ 2>/dev/null || true
                    cp -r backend/prisma deploy-package/backend/ 2>/dev/null || true
                    cp backend/package.json deploy-package/backend/ 2>/dev/null || true
                    cp backend/Dockerfile deploy-package/backend/ 2>/dev/null || true
                    cp backend/entrypoint.sh deploy-package/backend/ 2>/dev/null || true
                    cp backend/package-lock.json deploy-package/backend/ 2>/dev/null || true
                    chmod +x deploy-package/backend/entrypoint.sh 2>/dev/null || true
                    
                    # 复制 shared 包和 Docker 配置
                    if [ -d shared ]; then
                        cp -r shared deploy-package/
                    fi
                    mkdir -p deploy-package/docker
                    cp nginx/docker-compose.production.yml deploy-package/docker/ 2>/dev/null || true
                    cp nginx/nginx.conf.docker deploy-package/docker/ 2>/dev/null || true
                    cp scripts/deploy-docker.sh deploy-package/ 2>/dev/null || true
                    chmod +x deploy-package/deploy-docker.sh 2>/dev/null || true
                    
                    # 创建部署包
                    tar -czf deploy-package.tar.gz deploy-package/
                '''
            }
        }
        
        stage('Deploy') {
            steps {
                echo '部署到远程服务器...'
                sh '''
                    # 传输部署包
                    scp -o StrictHostKeyChecking=no deploy-package.tar.gz ${DEPLOY_USER}@${DEPLOY_HOST}:/tmp/
                    
                    # 在远程服务器上执行部署（deploy-docker.sh 已包含重启服务逻辑）
                    ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} bash << 'ENDSSH'
                        # 移除 set -e，改为手动检查关键命令
                        mkdir -p /opt/nginx/html/ai
                        cd /tmp && tar -xzf deploy-package.tar.gz
                        
                        # 备份旧版本
                        if [ -d /opt/nginx/html/ai/current ]; then
                            mv /opt/nginx/html/ai/current /opt/nginx/html/ai/backup-$(date +%Y%m%d-%H%M%S)
                        fi
                        
                        # 创建新版本目录并复制文件
                        mkdir -p /opt/nginx/html/ai/current/{backend,docker/logs}
                        cp -r deploy-package/frontend-dist/* /opt/nginx/html/ai/current/
                        cp -r deploy-package/backend/* /opt/nginx/html/ai/current/backend/
                        if [ -d deploy-package/shared ]; then
                            cp -r deploy-package/shared /opt/nginx/html/ai/current/
                        fi
                        # 复制 Docker 配置文件，确保文件名为 docker-compose.yml（podman-compose 需要）
                        if [ -f deploy-package/docker/docker-compose.production.yml ]; then
                            cp deploy-package/docker/docker-compose.production.yml /opt/nginx/html/ai/current/docker/docker-compose.yml
                        else
                            cp deploy-package/docker/* /opt/nginx/html/ai/current/docker/
                        fi
                        if [ -f deploy-package/docker/nginx.conf.docker ]; then
                            cp deploy-package/docker/nginx.conf.docker /opt/nginx/html/ai/current/docker/
                        fi
                        
                        # 执行部署脚本（包含停止、构建、启动和健康检查）
                        chmod +x deploy-package/deploy-docker.sh
                        DEPLOY_RESULT=0
                        bash deploy-package/deploy-docker.sh /opt/nginx/html/ai/current || DEPLOY_RESULT=$?
                        
                        if [ $DEPLOY_RESULT -eq 0 ]; then
                            echo "部署脚本执行成功"
                        else
                            echo "部署脚本执行失败，退出码: $DEPLOY_RESULT"
                            exit $DEPLOY_RESULT
                        fi
                        
                        # 清理临时文件
                        rm -rf /tmp/deploy-package /tmp/deploy-package.tar.gz || true
ENDSSH
                '''
            }
        }
    }
    
    post {
        success {
            echo '部署成功！'
        }
        failure {
            echo '部署失败！'
        }
        always {
            // 清理本地临时文件
            sh 'rm -rf deploy-package deploy-package.tar.gz'
        }
    }
}
