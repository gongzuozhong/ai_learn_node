# Nginx 配置说明

## 配置文件

- `nginx.conf` - 主配置文件

## 功能特性

1. **前端静态文件服务** - 服务 React 构建后的静态文件
2. **API 代理** - 将 `/api` 请求代理到后端服务器 (localhost:3001)
3. **SPA 路由支持** - 支持 React Router 的客户端路由
4. **静态资源缓存** - 优化静态资源加载性能
5. **健康检查** - `/health` 端点用于健康检查

## 部署步骤

### 1. 构建前端

```bash
cd frontend
npm run build
```

构建输出在 `frontend/dist/` 目录

### 2. 配置 Nginx

编辑 `nginx.conf` 文件，修改以下配置：

- `server_name`: 已设置为 `_`，支持通过 IP 地址访问（也可改为具体 IP 如 `192.168.1.100`）
- `root`: 改为前端构建文件的绝对路径（默认：`/var/www/ai-learning-platform/frontend/dist`）
- `upstream backend`: 确保后端服务器地址正确（默认：`localhost:3001`）

### 3. 安装配置文件

```bash
# 复制配置文件到 nginx 配置目录
sudo cp nginx/nginx.conf /etc/nginx/sites-available/ai-learning-platform

# 创建符号链接
sudo ln -s /etc/nginx/sites-available/ai-learning-platform /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重新加载 nginx
sudo systemctl reload nginx
```

### 4. 启动后端服务

确保后端服务在 3001 端口运行：

```bash
cd backend
npm run build
npm start
```

或者使用 PM2 管理：

```bash
pm2 start backend/dist/index.js --name ai-learning-backend
```

## 配置说明

### IP 地址访问

当前配置已设置为支持 IP 地址访问：
- `server_name _;` 表示匹配所有域名和 IP 地址
- 可以通过服务器的 IP 地址直接访问，如：`http://192.168.1.100`
- 如果需要限制为特定 IP，可以改为：`server_name 192.168.1.100;`

### 前端路径

默认配置假设前端构建文件在：
```
/var/www/ai-learning-platform/frontend/dist
```

请根据实际部署路径修改 `root` 指令。

**本地测试路径示例**：
```nginx
root /Users/yuchuncao/Documents/code/ai/frontend/dist;
```

### 后端代理

API 请求会被代理到：
```
http://localhost:3001
```

如果需要修改，编辑 `upstream backend` 部分。

**注意**：如果后端服务运行在不同的服务器上，需要修改为实际的 IP 地址：
```nginx
upstream backend {
    server 192.168.1.101:3001;  # 后端服务器 IP 和端口
    keepalive 64;
}
```

### 静态资源缓存

静态资源（JS、CSS、图片等）会缓存 1 年，提高性能。

### SPA 路由支持

`try_files $uri $uri/ /index.html;` 确保所有路由都返回 `index.html`，支持 React Router。

## HTTPS 配置（可选）

如果需要 HTTPS，取消注释配置文件中的 HTTPS 部分，并：

1. 获取 SSL 证书（Let's Encrypt 免费证书）
2. 修改证书路径
3. 重新加载 nginx

### 使用 Let's Encrypt

```bash
# 安装 certbot
sudo apt-get install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d yourdomain.com
```

## 性能优化

### Gzip 压缩

在 nginx 主配置文件中添加：

```nginx
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;
```

### 缓存优化

静态资源已配置长期缓存，生产环境建议使用 CDN。

## 监控和日志

- 访问日志：`/var/log/nginx/ai-learning-access.log`
- 错误日志：`/var/log/nginx/ai-learning-error.log`

## 故障排查

### 检查 nginx 状态

```bash
sudo systemctl status nginx
```

### 查看错误日志

```bash
sudo tail -f /var/log/nginx/ai-learning-error.log
```

### 测试配置

```bash
sudo nginx -t
```

### 重新加载配置

```bash
sudo systemctl reload nginx
```

## Docker 部署（可选）

如果使用 Docker，可以创建 `Dockerfile.nginx`：

```dockerfile
FROM nginx:alpine
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY frontend/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```
