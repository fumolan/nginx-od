#!/bin/bash
# ============================================
# Nginx 电商服务健康检查脚本
# ============================================
set -e

DOMAIN="${1:-shop.example.com}"
SERVICES=(
    "user:10.0.1.10:8080"
    "product:10.0.1.20:8081"
    "order:10.0.1.30:8082"
    "payment:10.0.1.40:8083"
    "notification:10.0.1.50:8084"
    "upload:10.0.1.60:8085"
    "admin:10.0.1.70:8086"
    "frontend:10.0.1.100:3000"
)

echo "=========================================="
echo "  Nginx 电商服务健康检查"
echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# 1. 检查 Nginx 进程
echo ""
echo "[1] Nginx 进程状态"
if pgrep -x nginx > /dev/null; then
    echo "  ✅ Nginx 运行中 (PID: $(pgrep -x nginx | tr '\n' ' '))"
else
    echo "  ❌ Nginx 未运行"
fi

# 2. 检查端口监听
echo ""
echo "[2] 端口监听"
for port in 80 443; do
    if ss -tlnp | grep -q ":$port "; then
        echo "  ✅ 端口 $port 已监听"
    else
        echo "  ❌ 端口 $port 未监听"
    fi
done

# 3. 检查 Nginx 配置
echo ""
echo "[3] Nginx 配置"
if nginx -t 2>&1 | grep -q "successful"; then
    echo "  ✅ 配置文件正确"
else
    echo "  ❌ 配置文件有误"
    nginx -t 2>&1
fi

# 4. 检查后端服务连通性
echo ""
echo "[4] 后端服务连通性"
for svc in "${SERVICES[@]}"; do
    name="${svc%%:*}"
    addr="${svc#*:}"
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://${addr}/health" 2>/dev/null | grep -q "200"; then
        echo "  ✅ ${name} (${addr})"
    else
        echo "  ❌ ${name} (${addr}) — 不可达"
    fi
done

# 5. 检查 SSL 证书过期
echo ""
echo "[5] SSL 证书"
CERT_FILE="/etc/nginx/ssl/fullchain.pem"
if [ -f "$CERT_FILE" ]; then
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
    echo "  ✅ 证书到期: $EXPIRY"
else
    echo "  ⚠️ 未找到证书文件 $CERT_FILE"
fi

echo ""
echo "=========================================="
echo "  检查完成"
echo "=========================================="
