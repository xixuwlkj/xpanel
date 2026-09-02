#!/bin/bash
# ============================================================
#  XPanel 希旭面板 - 在线一键安装引导脚本
#
#  使用方法（root 下执行，无需先下载任何文件）:
#     bash <(curl -sSL https://raw.githubusercontent.com/<你的GitHub用户名>/<仓库名>/main/sh/xp.sh)
#
#  可选环境变量:
#     PANEL_PORT=8888         面板端口
#     ADMIN_USER=admin        管理员用户名
#     ADMIN_PASS=xxxx         管理员密码（不填则随机生成）
#     NO_NGINX=1              不安装 Nginx
#     NO_PHP=1                不安装 PHP-FPM
#     NO_MAIL=1               不安装 Postfix+Dovecot
#  测试环境:
#     XPANEL_SKIP_ROOT=1      跳过 root 检查（Docker/CI 用）
#     XPANEL_SKIP_SYSTEMD=1   跳过 systemctl（Docker/CI 用）
# ============================================================

# ★★★ 改成你自己的 GitHub 仓库信息 ★★★
# 仓库名必须是公开仓库，文件结构:
#   <仓库>/release/xpanel.zip   面板安装包
#   <仓库>/sh/xp.sh             本脚本
GITHUB_USER="${GITHUB_USER:-xixuwlkj}"
GITHUB_REPO="${GITHUB_REPO:-xpanel}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"       # 分支
RAW_BASE="${XPANEL_RAW_BASE:-https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   XPanel 希旭面板 在线安装器 v1.0.0${NC}"
echo -e "${BLUE}============================================${NC}"

# ---------- 0. 仓库地址检查 ----------
if [ -z "$XPANEL_RAW_BASE" ] && { [ "$GITHUB_USER" = "你的用户名" ] || [ "$GITHUB_REPO" = "你的仓库名" ]; }; then
  echo -e "${RED}[错误] 本脚本尚未配置 GitHub 仓库地址。${NC}"
  echo -e "${RED}请先编辑 sh/xp.sh 顶部的 GITHUB_USER / GITHUB_REPO 为你自己的仓库，再上传到 GitHub。${NC}"
  exit 1
fi

# ---------- 1. root 检查 ----------
if [ "$(id -u)" != "0" ] && [ -z "$XPANEL_SKIP_ROOT" ]; then
  echo -e "${RED}[错误] 请使用 root 用户执行安装（sudo -i 或 sudo bash ...）${NC}"
  exit 1
fi

# ---------- 2. 基础工具检查 ----------
command -v curl >/dev/null 2>&1 || { echo -e "${YELLOW}[依赖] 安装 curl ...${NC}"; \
  (apt-get update >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1) || \
  (yum install -y curl >/dev/null 2>&1) || true; }
command -v unzip >/dev/null 2>&1 || { echo -e "${YELLOW}[依赖] 安装 unzip ...${NC}"; \
  (apt-get install -y unzip >/dev/null 2>&1) || (yum install -y unzip >/dev/null 2>&1) || true; }
command -v curl >/dev/null 2>&1 || { echo -e "${RED}[错误] 无法安装 curl，请手动安装后重试${NC}"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo -e "${RED}[错误] 无法安装 unzip，请手动安装后重试${NC}"; exit 1; }

# ---------- 3. 下载安装包 ----------
TMP_DIR="/tmp/xpanel_install_$$"
mkdir -p "$TMP_DIR"
echo -e "${GREEN}[1/3] 下载面板安装包 ...${NC}"

# 方式①：GitHub codeload —— 直接从 git 拉最新，不走 CDN 缓存（最可靠）
echo -e "     [方式1] codeload 拉取最新仓库 ..."
curl -sSL --retry 3 --retry-delay 2 -o "$TMP_DIR/repo.zip" "https://codeload.github.com/$GITHUB_USER/$GITHUB_REPO/zip/refs/heads/$GITHUB_BRANCH"
if [ -s "$TMP_DIR/repo.zip" ]; then
  cd "$TMP_DIR"
  unzip -oq repo.zip
  REPO_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name "${GITHUB_REPO}-*" | head -1)"
  [ -z "$REPO_DIR" ] && REPO_DIR="$TMP_DIR/${GITHUB_REPO}-${GITHUB_BRANCH}"
  if [ -f "$REPO_DIR/release/xpanel.zip" ]; then
    cp "$REPO_DIR/release/xpanel.zip" "$TMP_DIR/xpanel.zip"
    echo -e "     已获取最新安装包"
  fi
fi

# 方式②：回退 raw（codeload 失败时）
if [ ! -s "$TMP_DIR/xpanel.zip" ]; then
  echo -e "     [方式2] raw 下载 ..."
  curl -sSL --retry 3 --retry-delay 2 -o "$TMP_DIR/xpanel.zip" "$RAW_BASE/release/xpanel.zip"
fi
if [ ! -s "$TMP_DIR/xpanel.zip" ]; then
  echo -e "${RED}[错误] 下载失败，请检查:${NC}"
  echo -e "${RED}  1. 仓库是否公开${NC}"
  echo -e "${RED}  2. release/xpanel.zip 是否已上传${NC}"
  echo -e "${RED}  3. 分支名是否为 $GITHUB_BRANCH${NC}"
  rm -rf "$TMP_DIR"; exit 1
fi

# ---------- 4. 解压 ----------
echo -e "${GREEN}[2/3] 解压安装包 ...${NC}"
cd "$TMP_DIR"
unzip -oq xpanel.zip
if [ ! -f "$TMP_DIR/xpanel/install.sh" ]; then
  echo -e "${RED}[错误] 安装包结构不正确：未找到 xpanel/install.sh${NC}"
  rm -rf "$TMP_DIR"; exit 1
fi

# ---------- 5. 执行安装 ----------
echo -e "${GREEN}[3/3] 执行安装程序 ...${NC}"
echo ""
cd "$TMP_DIR/xpanel"
# 把用户设置的环境变量透传给安装脚本
export PANEL_PORT ADMIN_USER ADMIN_PASS NO_NGINX NO_PHP NO_MAIL \
       XPANEL_SKIP_ROOT XPANEL_SKIP_SYSTEMD XPANEL_INSTALL_DIR \
       XPANEL_WWW_ROOT XPANEL_NGINX_VHOST_DIR XPANEL_MAIL_ROOT_DIR
bash install.sh
RC=$?

# ---------- 6. 清理 ----------
cd /tmp
rm -rf "$TMP_DIR"

exit $RC
