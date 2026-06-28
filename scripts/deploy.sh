#!/bin/bash
# ============================================
# Nginx 配置部署脚本
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NGINX_CONF_DIR="/etc/nginx"

if [ ! -d "$NGINX_CONF_DIR" ]; then
    NGINX_CONF_DIR="/usr/local/nginx/conf"
fi

echo "[INFO] 部署配置到 ${NGINX_CONF_DIR}..."

# 备份原配置
BACKUP_DIR="${NGINX_CONF_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
echo "[INFO] 备份原配置到 ${BACKUP_DIR}"
mkdir -p "$BACKUP_DIR"
cp -r "${NGINX_CONF_DIR}/nginx.conf" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "${NGINX_CONF_DIR}/conf.d" "$BACKUP_DIR/" 2>/dev/null || true

# 复制新配置
echo "[INFO] 复制新配置..."
cp "${PROJECT_DIR}/config/nginx.conf" "${NGINX_CONF_DIR}/nginx.conf"
mkdir -p "${NGINX_CONF_DIR}/conf.d"
cp "${PROJECT_DIR}/config/conf.d/"*.conf "${NGINX_CONF_DIR}/conf.d/"

# 测试配置
echo "[INFO] 测试配置..."
nginx -t

if [ $? -eq 0 ]; then
    echo "[INFO] 配置正确，重载 Nginx..."
    nginx -s reload 2>/dev/null || systemctl reload nginx 2>/dev/null || echo "  ⚠️ 请手动重载: nginx -s reload"
    echo "[DONE] 部署成功！"
else
    echo "[ERROR] 配置测试失败，请检查！"
    echo "  备份位于: ${BACKUP_DIR}"
    exit 1
fi
