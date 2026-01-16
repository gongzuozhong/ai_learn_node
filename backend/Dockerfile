FROM node:22-alpine

# 安装 OpenSSL（Prisma 需要）
# Alpine 3.19+ 使用 openssl3，旧版本使用 openssl1.1-compat
RUN apk add --no-cache openssl libc6-compat || \
    apk add --no-cache openssl1.1-compat || \
    apk add --no-cache openssl

WORKDIR /app

# 先复制 shared 包（workspace 依赖）
COPY shared ./shared

# 复制 backend 的 package 文件
COPY backend/package*.json ./
COPY backend/prisma ./prisma/

# 安装依赖（shared 包直接使用源码，不需要安装）
# 修改 package.json 中的 shared 依赖为 file:./shared
RUN sed -i 's|"@ai-learning/shared": "\*"|"@ai-learning/shared": "file:./shared"|' package.json && \
    npm install --production

# 安装 tsx（用于执行 seed.ts）
RUN npm install -g tsx || npm install tsx --save-dev || true

# 复制构建产物
COPY backend/dist ./dist

# 复制并设置 entrypoint 脚本
COPY backend/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 生成 Prisma Client（在构建时生成，启动时也会重新生成以确保最新）
RUN npx prisma generate

# 暴露端口
EXPOSE 3001

# 使用 entrypoint 脚本启动（会自动执行数据库迁移）
CMD ["/app/entrypoint.sh"]
