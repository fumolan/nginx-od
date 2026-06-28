#!/bin/bash
# ============================================
# Nginx 源码编译安装脚本
# ============================================
set -e

NGINX_VERSION="1.25.3"
NGINX_URL="https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
INSTALL_PREFIX="/usr/local/nginx"

echo "[INFO] 安装依赖..."
if command -v apt &>/dev/null; then
    sudo apt update
    sudo apt install build-essential libpcre3-dev zlib1g-dev libssl-dev -y
elif command -v yum &>/dev/null; then
    sudo yum install gcc pcre-devel zlib-devel openssl-devel -y
else
    echo "[ERROR] 不支持的系统包管理器"
    exit 1
fi

echo "[INFO] 下载 Nginx ${NGINX_VERSION}..."
cd /tmp
wget -q "$NGINX_URL" -O "nginx-${NGINX_VERSION}.tar.gz"
tar -zxvf "nginx-${NGINX_VERSION}.tar.gz"
cd "nginx-${NGINX_VERSION}"

echo "[INFO] 编译配置..."
./configure \
    --prefix=${INSTALL_PREFIX} \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --with-stream=dynamic \
    --with-threads

echo "[INFO] 编译安装..."
make && sudo make install

echo "[INFO] 创建配置目录..."
sudo mkdir -p ${INSTALL_PREFIX}/conf/conf.d
sudo mkdir -p ${INSTALL_PREFIX}/conf/ssl

echo ""
echo "[DONE] Nginx ${NGINX_VERSION} 安装完成！"
echo "  安装路径: ${INSTALL_PREFIX}"
echo "  配置文件: ${INSTALL_PREFIX}/conf/nginx.conf"
echo ""
echo "  将本项目 config/ 下的文件复制到 ${INSTALL_PREFIX}/conf/ 即可使用"
