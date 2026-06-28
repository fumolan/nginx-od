# Nginx 电商网站高并发部署工程

## 目录结构

```
nginx-ecommerce-deploy/
├── README.md                      # 项目说明
├── docs/
│   └── manual.md                  # 完整部署手册（含架构说明）
├── config/
│   ├── nginx.conf                 # Nginx 主配置文件
│   ├── mime.types                 # MIME 类型定义
│   └── conf.d/
│       ├── ecommerce.conf         # 电商网站虚拟主机配置
│       ├── upstreams.conf         # 上游微服务定义
│       ├── ssl.conf               # SSL/TLS 配置
│       ├── rate-limit.conf        # 限流配置
│       ├── cache.conf             # 缓存策略配置
│       ├── security.conf          # 安全加固配置
│       └── error-pages.conf       # 错误页面配置
├── errors/
│   ├── 404.html                   # 404 错误页面
│   ├── 403.html                   # 403 禁止访问页面
│   ├── 429.html                   # 429 限流页面
│   └── 50x.html                   # 500/502/503/504 服务异常页面
├── scripts/
│   ├── install.sh                 # 编译安装脚本
│   ├── deploy.sh                  # 部署与配置同步
│   ├── healthcheck.sh             # 服务健康检查
│   └── logrotate.conf             # 日志轮转配置
└── docker-compose.yml             # Docker 编排（可选）
```

## 快速开始

```bash
# 1. 编译安装 Nginx
bash scripts/install.sh

# 2. 部署配置（复制 config/ 到 /etc/nginx/）
bash scripts/deploy.sh

# 3. 复制错误页面到网站根目录
mkdir -p /var/www/ecommerce/errors
cp errors/*.html /var/www/ecommerce/errors/

# 4. 检查配置
nginx -t

# 5. 启动
nginx
```

## 配置说明

| 文件 | 说明 |
|------|------|
| `nginx.conf` | 全局配置：worker、events、http、gzip |
| `mime.types` | 静态资源的 MIME 类型映射 |
| `upstreams.conf` | 微服务集群地址（user/product/order/payment） |
| `ecommerce.conf` | 虚拟主机 + API 路由 + 静态资源 |
| `ssl.conf` | HTTPS 证书 + TLS 1.2/1.3 + HSTS |
| `rate-limit.conf` | 全局限流 + 秒杀限流 + 登录防暴力破解 |
| `cache.conf` | 商品详情页缓存 + API 缓存策略 |
| `security.conf` | SQL/XSS 过滤 + IP 黑白名单 + 安全头部 |
| `error-pages.conf` | 自定义错误页面路由 |

## 适用场景

- 电商网站高并发微服务架构
- 需要 Nginx 反向代理 + 负载均衡 + 限流 + 缓存
- 多微服务统一网关入口
- 秒杀活动流量控制

## License

MIT