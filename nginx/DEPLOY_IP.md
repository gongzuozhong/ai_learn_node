# 使用 IP 地址部署指南

## 快速部署步骤

### 1. 构建前端

```bash
cd frontend
npm run build
```

构建完成后，文件在 `frontend/dist/` 目录。

### 2. 修改 Nginx 配置

编辑 `nginx/nginx.conf`，主要修改前端文件路径：

```nginx
# 前端静态文件路径（根据实际路径修改）
location / {
    root /path/to/your/project/frontend/dist;  # 修改这里
    index index.html;
    try_files $uri $uri/ /index.html;
}
```

**示例路径**：
- Linux: `/var/www/ai-learning-platform/frontend/dist`
- macOS: `/Users/yourname/Documents/code/ai/frontend/dist`
- Windows: `C:\projects\ai-learning-platform\frontend\dist`

### 3. 启动后端服务

确保后端在 3001 端口运行：

```bash
cd backend
npm run build
npm start
```

或者使用 PM2：

```bash
pm2 start backend/dist/index.js --name ai-learning-backend
```

### 4. 安装并启动 Nginx

#### Linux (Ubuntu/Debian)

```bash
# 安装 nginx
sudo apt-get update
sudo apt-get install nginx

# 复制配置文件
sudo cp nginx/nginx.conf /etc/nginx/sites-available/ai-learning-platform

# 创建符号链接
sudo ln -s /etc/nginx/sites-available/ai-learning-platform /etc/nginx/sites-enabled/

# 删除默认配置（可选）
sudo rm /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 启动 nginx
sudo systemctl start nginx
sudo systemctl enable nginx  # 开机自启
```

#### macOS

```bash
# 安装 nginx (使用 Homebrew)
brew install nginx

# 复制配置文件
sudo cp nginx/nginx.conf /opt/homebrew/etc/nginx/servers/ai-learning-platform.conf

# 测试配置
sudo nginx -t

# 启动 nginx
sudo nginx
```

### 5. 访问应用

在浏览器中访问：

```
http://服务器IP地址
```

例如：
- `http://192.168.1.100`
- `http://localhost` (本地访问)
- `http://127.0.0.1` (本地访问)

### 6. 检查服务状态

```bash
# 检查 nginx 状态
sudo systemctl status nginx  # Linux
sudo nginx -t                # 测试配置

# 检查后端服务
curl http://localhost:3001/api/health

# 检查前端
curl http://localhost/
```

## 常见问题

### 1. 无法访问

**检查防火墙**：
```bash
# Linux
sudo ufw allow 80/tcp
sudo ufw status

# 检查端口是否被占用
sudo netstat -tulpn | grep :80
```

### 2. 403 Forbidden

- 检查前端文件路径是否正确
- 检查文件权限：`sudo chmod -R 755 /path/to/frontend/dist`
- 检查 nginx 用户权限

### 3. API 请求失败

- 确保后端服务在 3001 端口运行
- 检查 `upstream backend` 配置
- 查看 nginx 错误日志：`sudo tail -f /var/log/nginx/ai-learning-error.log`

### 4. 页面空白

- 检查浏览器控制台错误
- 确认前端构建成功
- 检查 nginx 访问日志：`sudo tail -f /var/log/nginx/ai-learning-access.log`

## 获取服务器 IP 地址

### Linux/macOS

```bash
# 查看本机 IP
ifconfig
# 或
ip addr show

# 查看公网 IP（如果有）
curl ifconfig.me
```

### 局域网访问

如果服务器在局域网中，其他设备可以通过局域网 IP 访问：
- 确保防火墙允许 80 端口
- 使用局域网 IP，如：`http://192.168.1.100`

## 性能优化建议

1. **启用 Gzip 压缩**（在 nginx 主配置中）：
```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
```

2. **调整工作进程数**（根据 CPU 核心数）：
```nginx
worker_processes auto;
```

3. **启用缓存**（已在配置中）：
- 静态资源已配置 1 年缓存

## 下一步

配置完成后，可以通过 IP 地址访问应用。如果需要使用域名，可以：
1. 配置 DNS 解析
2. 修改 `server_name` 为域名
3. 配置 SSL 证书（HTTPS）
