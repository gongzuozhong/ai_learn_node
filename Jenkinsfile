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
                    # 检查 Node.js
                    if ! command -v node &> /dev/null; then
                        echo "错误: Node.js 未安装，请安装 Node.js 22+"
                        exit 1
                    fi
                    
                    echo "Node 版本: $(node --version)"
                    echo "NPM 版本: $(npm --version)"
                    
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
                    npm run build
                    npm run prisma:generate
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
                    cp -r backend/{dist,prisma} deploy-package/backend/
                    cp backend/{package.json,Dockerfile,entrypoint.sh} deploy-package/backend/ 2>/dev/null || true
                    cp backend/package-lock.json deploy-package/backend/ 2>/dev/null || true
                    chmod +x deploy-package/backend/entrypoint.sh 2>/dev/null || true
                    
                    # 复制 shared 包和 Docker 配置
                    [ -d shared ] && cp -r shared deploy-package/
                    mkdir -p deploy-package/docker
                    cp nginx/{docker-compose.production.yml,nginx.conf.docker} deploy-package/docker/
                    cp scripts/deploy-docker.sh deploy-package/ && chmod +x deploy-package/deploy-docker.sh
                    
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
                    ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} << 'ENDSSH'
                        set -e
                        mkdir -p /opt/nginx/html/ai
                        cd /tmp && tar -xzf deploy-package.tar.gz
                        
                        # 备份旧版本
                        [ -d /opt/nginx/html/ai/current ] && \
                            mv /opt/nginx/html/ai/current /opt/nginx/html/ai/backup-$(date +%Y%m%d-%H%M%S)
                        
                        # 创建新版本目录并复制文件
                        mkdir -p /opt/nginx/html/ai/current/{backend,docker/logs}
                        cp -r deploy-package/frontend-dist/* /opt/nginx/html/ai/current/
                        cp -r deploy-package/backend/* /opt/nginx/html/ai/current/backend/
                        [ -d deploy-package/shared ] && cp -r deploy-package/shared /opt/nginx/html/ai/current/
                        cp deploy-package/docker/* /opt/nginx/html/ai/current/docker/
                        
                        # 执行部署脚本（包含停止、构建、启动和健康检查）
                        chmod +x deploy-package/deploy-docker.sh
                        bash deploy-package/deploy-docker.sh /opt/nginx/html/ai/current
                        
                        # 清理临时文件
                        rm -rf /tmp/deploy-package /tmp/deploy-package.tar.gz
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
