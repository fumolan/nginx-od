# Nginx 电商网站高并发部署工程

## 目录结构

```
nginx-ecommerce-deploy/
├── README.md                 # 项目说明
├── docs/
│   └── manual.md             # 完整部署手册（含架构说明）
├── config/
│   ├── nginx.conf            # Nginx 主配置文件
│   ├── conf.d/
│   │   ├── ecommerce.conf    # 电商网站虚拟主机配置
│   │   ├── upstreams.conf    # 上游微服务定义
│   │   ├── ssl.conf          # SSL/TLS 配置
│   │   ├── rate-limit.conf   # 限流配置
│   │   ├── cache.conf        # 缓存策略配置
│   │   └── security.conf     # 安全加固配置
│   └── mime.types            # MIME 类型定义
├── scripts/
│   ├── install.sh            # 编译安装脚本
│   ├── deploy.sh             # 部署与配置同步
│   ├── healthcheck.sh        # 服务健康检查
│   └── logrotate.conf        # 日志轮转配置
└── docker-compose.yml        # Docker 编排（可选）
```

## 快速开始

```bash
# 1. 编译安装 Nginx
bash scripts/install.sh

# 2. 部署配置
bash scripts/deploy.sh

# 3. 检查配置
nginx -t

# 4. 启动
nginx
```

## 适用场景

- 电商网站高并发微服务架构
- 需要 Nginx 反向代理 + 负载均衡 + 限流 + 缓存
- 多微服务统一网关入口
