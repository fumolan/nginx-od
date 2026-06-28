# Nginx 电商网站高并发部署完整手册

## 目录
1. [架构设计概述](#架构设计概述)
2. [环境准备与安装](#环境准备与安装)
3. [核心配置详解](#核心配置详解)
4. [微服务转发配置](#微服务转发配置)
5. [高并发优化策略](#高并发优化策略)
6. [安全防护配置](#安全防护配置)
7. [监控与运维](#监控与运维)
8. [故障排查指南](#故障排查指南)

---

## 架构设计概述

### 电商网站典型架构
```
客户端 → CDN → Nginx负载均衡层 → 微服务集群 → 缓存层 → 数据库层
```

### Nginx在架构中的角色
- **反向代理**：隐藏后端微服务真实地址
- **负载均衡**：分发流量到多个服务实例
- **SSL终止**：统一处理HTTPS加密解密
- **静态资源服务**：直接提供图片、CSS、JS等文件
- **API网关**：统一入口，实现路由、限流、认证等功能

---

## 环境准备与安装

### 2.1 系统要求
- **操作系统**：CentOS 7+/Ubuntu 18.04+
- **内存**：建议8GB以上（高并发场景）
- **CPU**：4核以上
- **磁盘**：SSD存储，至少50GB可用空间

### 2.2 源码编译安装（推荐）
```bash
# 安装依赖
sudo apt install build-essential libpcre3-dev zlib1g-dev libssl-dev -y # Ubuntu/Debian
sudo yum install gcc pcre-devel zlib-devel openssl-devel -y # CentOS/RHEL

# 下载并编译Nginx
wget https://nginx.org/download/nginx-1.25.3.tar.gz
tar -zxvf nginx-1.25.3.tar.gz
cd nginx-1.25.3

./configure \
 --prefix=/usr/local/nginx \
 --with-http_ssl_module \
 --with-http_v2_module \
 --with-http_realip_module \
 --with-http_gzip_static_module \
 --with-http_stub_status_module \
 --with-stream=dynamic \
 --with-threads

make && sudo make install
```

### 2.3 目录结构说明
```
/usr/local/nginx/
├── conf/ # 配置文件目录
│ ├── nginx.conf # 主配置文件
│ ├── mime.types # MIME类型定义
│ └── vhosts/ # 虚拟主机配置
├── html/ # 默认网站根目录
├── logs/ # 日志文件目录
└── sbin/ # 可执行文件
```

---

## 核心配置详解

### 3.1 主配置文件 (nginx.conf)
```nginx
# 全局配置
user nginx;
worker_processes auto; # 自动匹配CPU核心数
worker_rlimit_nofile 65535; # 最大文件描述符数
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

# 事件驱动配置
events {
 worker_connections 10240; # 单进程最大连接数
 use epoll; # Linux高效事件模型
 multi_accept on; # 一次接受所有新连接
}

# HTTP服务配置
http {
 include /etc/nginx/mime.types;
 default_type application/octet-stream;

 # 日志格式
 log_format main '$remote_addr - $remote_user [$time_local] "$request" '
 '$status $body_bytes_sent "$http_referer" '
 '"$http_user_agent" "$http_x_forwarded_for"';

 access_log /var/log/nginx/access.log main;

 # 性能优化
 sendfile on;
 tcp_nopush on;
 tcp_nodelay on;
 keepalive_timeout 65;
 types_hash_max_size 2048;

 # Gzip压缩
 gzip on;
 gzip_vary on;
 gzip_proxied any;
 gzip_comp_level 6;
 gzip_min_length 256;
 gzip_types
 text/plain text/css application/json application/javascript
 text/xml application/xml application/xml+rss text/javascript
 image/svg+xml application/vnd.ms-fontobject font/ttf font/opentype;

 # 包含虚拟主机配置
 include /etc/nginx/conf.d/*.conf;
}
```

### 3.2 电商网站虚拟主机配置
```nginx
# /etc/nginx/conf.d/ecommerce.conf
upstream user_service {
 zone user_service 64k;
 least_conn;
 server 10.0.1.10:8080 weight=3 max_fails=3 fail_timeout=30s;
 server 10.0.1.11:8080 weight=2 max_fails=3 fail_timeout=30s;
 server 10.0.1.12:8080 weight=2 max_fails=3 fail_timeout=30s;
 server 10.0.1.13:8080 backup; # 备份服务器
}

upstream product_service {
 zone product_service 64k;
 least_conn;
 server 10.0.1.20:8081 weight=3 max_fails=3 fail_timeout=30s;
 server 10.0.1.21:8081 weight=2 max_fails=3 fail_timeout=30s;
 server 10.0.1.22:8081 weight=2 max_fails=3 fail_timeout=30s;
}

upstream order_service {
 zone order_service 64k;
 least_conn;
 server 10.0.1.30:8082 weight=3 max_fails=3 fail_timeout=30s;
 server 10.0.1.31:8082 weight=2 max_fails=3 fail_timeout=30s;
}

upstream payment_service {
 zone payment_service 64k;
 least_conn;
 server 10.0.1.40:8083 weight=2 max_fails=3 fail_timeout=30s;
 server 10.0.1.41:8083 weight=2 max_fails=3 fail_timeout=30s;
}

server {
 listen 80;
 server_name shop.example.com www.shop.example.com;

 # HTTP强制跳转HTTPS
 return 301 https://$host$request_uri;
}

server {
 listen 443 ssl http2;
 server_name shop.example.com www.shop.example.com;

 # SSL证书配置
 ssl_certificate /etc/nginx/ssl/fullchain.pem;
 ssl_certificate_key /etc/nginx/ssl/privkey.pem;
 ssl_protocols TLSv1.2 TLSv1.3;
 ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
 ssl_prefer_server_ciphers on;
 ssl_session_cache shared:SSL:10m;
 ssl_session_timeout 1h;

 # HSTS头部
 add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

 # 静态资源处理
 location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf)$ {
 root /var/www/ecommerce/static;
 expires 365d;
 add_header Cache-Control "public, immutable";
 access_log off;
 }

 # 用户服务路由
 location /api/users/ {
 proxy_pass http://user_service/;
 proxy_set_header Host $host;
 proxy_set_header X-Real-IP $remote_addr;
 proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
 proxy_set_header X-Forwarded-Proto $scheme;
 proxy_connect_timeout 5s;
 proxy_read_timeout 30s;
 proxy_send_timeout 30s;
 }

 # 商品服务路由
 location /api/products/ {
 proxy_pass http://product_service/;
 proxy_set_header Host $host;
 proxy_set_header X-Real-IP $remote_addr;
 proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
 proxy_set_header X-Forwarded-Proto $scheme;
 proxy_connect_timeout 5s;
 proxy_read_timeout 30s;
 proxy_send_timeout 30s;
 }

 # 订单服务路由
 location /api/orders/ {
 proxy_pass http://order_service/;
 proxy_set_header Host $host;
 proxy_set_header X-Real-IP $remote_addr;
 proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
 proxy_set_header X-Forwarded-Proto $scheme;
 proxy_connect_timeout 5s;
 proxy_read_timeout 60s; # 订单处理可能较慢
 proxy_send_timeout 60s;
 }

 # 支付服务路由
 location /api/payments/ {
 proxy_pass http://payment_service/;
 proxy_set_header Host $host;
 proxy_set_header X-Real-IP $remote_addr;
 proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
 proxy_set_header X-Forwarded-Proto $scheme;
 proxy_connect_timeout 10s;
 proxy_read_timeout 120s; # 支付处理可能需要较长时间
 proxy_send_timeout 120s;
 }

 # 前端应用路由
 location / {
 proxy_pass http://frontend_service:3000;
 proxy_set_header Host $host;
 proxy_set_header X-Real-IP $remote_addr;
 proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
 proxy_set_header X-Forwarded-Proto $scheme;
 }

 # 健康检查端点
 location /health {
 access_log off;
 return 200 "healthy\n";
 add_header Content-Type text/plain;
 }
}
```

---

## 微服务转发配置

### 4.1 动态上游配置
```nginx
# 支持动态服务发现的配置示例
upstream dynamic_backend {
 zone backend 64k;
 # 使用resolver进行DNS解析
 server backend.service.consul resolve;
 # 或者使用变量方式
 # server $backend_address resolve;
}

resolver 127.0.0.11 valid=10s; # Docker DNS或Consul DNS

server {
 listen 80;
 server_name api.example.com;

 location / {
 set $backend_address "service-name.default.svc.cluster.local";
 proxy_pass http://$backend_address;
 proxy_set_header Host $host;
 proxy_set_header X-Real-IP $remote_addr;
 }
}
```

### 4.2 WebSocket支持
```nginx
# 支持实时通信（如聊天、订单状态推送）
location /ws/ {
 proxy_pass http://notification_service:8084;
 proxy_http_version 1.1;
 proxy_set_header Upgrade $http_upgrade;
 proxy_set_header Connection "upgrade";
 proxy_set_header Host $host;
 proxy_read_timeout 86400; # WebSocket长连接
}
```

### 4.3 文件上传优化
```nginx
# 大文件上传配置（商品图片、视频等）
location /api/uploads/ {
 client_max_body_size 500m; # 最大上传文件大小
 client_body_buffer_size 128k; # 请求体缓冲区大小
 client_body_temp_path /tmp/nginx_body_temp;

 proxy_pass http://upload_service:8085;
 proxy_request_buffering off; # 禁用请求缓冲，直接流式传输
 proxy_connect_timeout 300s;
 proxy_read_timeout 300s;
 proxy_send_timeout 300s;
}
```

---

## 高并发优化策略

### 5.1 连接池优化
```nginx
# 在upstream块中启用keepalive
upstream backend_pool {
 server 10.0.1.10:8080;
 server 10.0.1.11:8080;

 # 启用连接复用
 keepalive 32; # 每个worker进程保持的空闲连接数

 # 健康检查
 zone backend 64k;
 least_conn;
}

server {
 location /api/ {
 proxy_pass http://backend_pool;
 proxy_http_version 1.1;
 proxy_set_header Connection "";
 # 其他proxy设置...
 }
}
```

### 5.2 缓存策略
```nginx
# 页面级缓存配置
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:100m inactive=60m max_size=10g;

server {
 # 商品详情页缓存
 location ~ ^/products/(\d+)$ {
 proxy_pass http://product_service;
 proxy_cache my_cache;
 proxy_cache_valid 200 302 10m;
 proxy_cache_valid 404 1m;
 proxy_cache_lock on; # 防止缓存击穿
 proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;

 # 缓存键设计
 proxy_cache_key "$scheme$request_method$host$request_uri$is_args$args";
 }

 # API响应缓存
 location /api/products/popular {
 proxy_pass http://product_service;
 proxy_cache my_cache;
 proxy_cache_valid 200 5m; # 热门商品缓存5分钟
 proxy_cache_lock on;
 }
}
```

### 5.3 限流配置
```nginx
# 全局限流
limit_req_zone $binary_remote_addr zone=global_limit:10m rate=100r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

# 秒杀活动专用限流
limit_req_zone $binary_remote_addr zone=flash_sale:10m rate=10r/s;

server {
 # 全局请求限制
 location / {
 limit_req zone=global_limit burst=20 nodelay;
 limit_conn conn_limit 50;
 # ... 其他配置
 }

 # 秒杀接口严格限流
 location /api/flash-sale/ {
 limit_req zone=flash_sale burst=5 nodelay;
 limit_req_status 429;
 proxy_pass http://order_service;
 }

 # 登录接口防暴力破解
 location /api/auth/login {
 limit_req zone=login_limit burst=3 nodelay;
 limit_req_status 429;
 proxy_pass http://user_service;
 }
}
```

### 5.4 日志优化
```nginx
# 日志缓冲写入，减少磁盘I/O
access_log /var/log/nginx/access.log main buffer=32k flush=5s;

# 关闭不需要的访问日志
location /health {
 access_log off;
 return 200 "healthy\n";
}

# 错误日志级别控制
error_log /var/log/nginx/error.log warn;
```

---

## 安全防护配置

### 6.1 基础安全加固
```nginx
# 隐藏Nginx版本号
server_tokens off;

# 限制请求方法
if ($request_method !~ ^(GET|HEAD|POST|PUT|DELETE|OPTIONS)$) {
 return 405;
}

# 防止点击劫持
add_header X-Frame-Options "SAMEORIGIN" always;

# 防止MIME类型嗅探
add_header X-Content-Type-Options "nosniff" always;

# 启用XSS保护
add_header X-XSS-Protection "1; mode=block" always;

# 内容安全策略
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;" always;

# 引用来源策略
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

### 6.2 防SQL注入与XSS
```nginx
# 在Nginx层过滤恶意请求
location /api/ {
 # 过滤SQL注入关键词
 if ($query_string ~* "(\bselect\b|\bunion\b|\binsert\b|\bdelete\b|\bdrop\b|\bupdate\b|\bcreate\b|\balter\b)") {
 return 403;
 }

 # 过滤XSS攻击关键词
 if ($query_string ~* "(<script|<iframe|<object|<embed|<applet)") {
 return 403;
 }

 proxy_pass http://backend_pool;
}
```

### 6.3 IP黑白名单
```nginx
# 白名单配置（仅允许特定IP访问管理后台）
location /admin/ {
 allow 10.0.0.0/8;
 allow 172.16.0.0/12;
 allow 192.168.0.0/16;
 deny all;
 proxy_pass http://admin_service:8086;
}

# 黑名单配置（封禁恶意IP）
location /api/ {
 deny 1.2.3.4; # 恶意IP
 deny 5.6.7.0/24; # 恶意IP段
 allow all;
 proxy_pass http://backend_pool;
}
```

### 6.4 防止DDoS攻击
```nginx
# 限制连接速率
limit_conn_zone $binary_remote_addr zone=ddos_limit:10m;

server {
 # 单IP最大连接数限制
 location / {
 limit_conn ddos_limit 10;
 limit_conn_status 503;
 }

 # 慢速连接防护
 client_body_timeout 10s;
 client_header_timeout 10s;
 send_timeout 10s;
}
```

---

## 监控与运维

### 7.1 状态监控页面
```nginx
# 启用Nginx状态监控
server {
 listen 127.0.0.1:8080;
 location /nginx_status {
 stub_status on;
 access_log off;
 allow 127.0.0.1;
 deny all;
 }
}
```

### 7.2 请求日志分析
```nginx
# JSON格式日志，便于日志分析系统处理
log_format json escape=json '{'
 '"time_local":"$time_local",'
 '"remote_addr":"$remote_addr",'
 '"remote_user":"$remote_user",'
 '"request":"$request",'
 '"status":$status,'
 '"body_bytes_sent":$body_bytes_sent,'
 '"request_time":$request_time,'
 '"upstream_response_time":"$upstream_response_time",'
 '"http_referer":"$http_referer",'
 '"http_user_agent":"$http_user_agent",'
 '"http_x_forwarded_for":"$http_x_forwarded_for"'
 '}';

access_log /var/log/nginx/access.json json;
```

### 7.3 自动重载与优雅重启
```bash
# 测试配置是否正确
nginx -t

# 优雅重载配置（不中断现有连接）
nginx -s reload

# 优雅停止（等待当前请求处理完毕）
nginx -s quit

# 立即停止
nginx -s stop

# 重新打开日志文件（日志轮转时使用）
nginx -s reopen
```

### 7.4 日志轮转配置
```bash
# /etc/logrotate.d/nginx
/var/log/nginx/*.log {
 daily
 missingok
 rotate 30
 compress
 delaycompress
 notifempty
 create 640 nginx adm
 sharedscripts
 postrotate
 [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
 endscript
}
```

---

## 故障排查指南

### 8.1 常见问题与解决方案

#### 502 Bad Gateway
```bash
# 检查后端服务是否正常运行
curl -I http://backend_host:port/health

# 检查Nginx错误日志
tail -f /var/log/nginx/error.log

# 常见原因：后端服务挂掉、连接超时、缓冲区不足
```

#### 504 Gateway Timeout
```nginx
# 解决方案：增加超时时间
proxy_connect_timeout 60s;
proxy_read_timeout 60s;
proxy_send_timeout 60s;
```

#### 413 Request Entity Too Large
```nginx
# 解决方案：增加上传文件大小限制
client_max_body_size 100m;
```

#### 连接数不足
```nginx
# 解决方案：优化系统参数
# /etc/sysctl.conf
net.core.somaxconn = 65535
net.ipv4.tcp_max_tw_buckets = 20000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_syncookies = 1
net.core.netdev_max_backlog = 100000
```

### 8.2 性能诊断命令
```bash
# 查看Nginx工作进程
ps aux | grep nginx

# 查看连接状态
ss -tlnp | grep nginx

# 查看当前活跃连接数
curl http://127.0.0.1:8080/nginx_status

# 测试配置文件
nginx -t

# 查看编译模块
nginx -V

# 压力测试（需安装ab）
ab -n 10000 -c 100 http://your-domain.com/
```

### 8.3 紧急恢复流程
```bash
# 1. 检查Nginx进程状态
systemctl status nginx

# 2. 查看错误日志
tail -100 /var/log/nginx/error.log

# 3. 尝试重启
systemctl restart nginx

# 4. 如果无法启动，回滚到上一个配置
cp /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
nginx -t && systemctl restart nginx

# 5. 检查后端服务连通性
for service in user product order payment; do
 echo "Checking $service..."
 curl -s -o /dev/null -w "%{http_code}" http://10.0.1.10:8080/health
done
```

### 8.4 配置变更最佳实践
```bash
# 1. 修改配置前备份
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.$(date +%Y%m%d_%H%M%S)

# 2. 测试配置
nginx -t

# 3. 优雅重载
nginx -s reload

# 4. 验证新配置生效
curl -I https://shop.example.com/
```

---

## 附录

### A. 常用命令速查
| 命令 | 说明 |
|------|------|
| `nginx -t` | 测试配置文件 |
| `nginx -s reload` | 优雅重载配置 |
| `nginx -s quit` | 优雅停止 |
| `nginx -s stop` | 立即停止 |
| `nginx -V` | 查看编译参数和模块 |
| `systemctl status nginx` | 查看服务状态 |
| `systemctl restart nginx` | 重启服务 |

### B. 性能调优参考
- **静态资源**：使用CDN + Nginx缓存，减少后端压力
- **动态请求**：启用upstream keepalive，减少TCP连接开销
- **SSL优化**：使用TLS 1.3 + session cache，减少握手开销
- **日志优化**：使用buffer写入，减少磁盘I/O
- **系统参数**：调整内核参数，支持更高并发

### C. 推荐监控工具
- **Prometheus + Grafana**：Nginx指标监控
- **ELK Stack**：日志收集与分析
- **Nginx Amplify**：官方监控工具
- **Datadog**：全栈监控
- **Alibaba Cloud Monitor**：云原生监控
