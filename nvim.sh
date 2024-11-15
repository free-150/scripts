#!/usr/bin/env bash
# CLI命令
# 库文件必须使用函数包围
set -e
# set -x
version=1.0
# 初始化默认值
is_mirror=""

show_helps() {
  cat <<EOF
用法: 脚本 [选项] [参数]

选项:
  -h, --help          帮助
  -m, --mirror        镜像
  -v, --version       版本
  -p, --proxy         代理
EOF
}

is_CLI() {
args=$(getopt -o hm:vp: -l mirror:,help,version,proxy: -- "$@")
eval set -- "$args"

# 处理短选项
while true; do
  case "$1" in
  -h|--help)
    show_helps
    shift
    ;;
  -m|--mirror)
    echo "你的镜像加速地址为:$2"
    # 格式化 URL，如果没有 '/' 就追加
    if [[ "$2" != */ ]]; then
      is_mirror="${2}/"
    else
      is_mirror="$2"
    fi
    shift 2
    ;;
  -p|--proxy)
    echo "你的代理地址为:$2"
    export http_proxy=$2 && export https_proxy=$2
    shift 2
    ;;
  -v|--version)
    echo "当前版本:$version"
    shift
    ;;
  --)
    break # 循环到结束标记--就跳出循环
    ;;
  *)
    echo "错误选项或参数"
    show_helps
    exit 1
    ;;
  esac
done
}

# 架构检查
# Get platform
is_platform() {
if command -v uname >/dev/null 2>&1; then
	platform=$(uname -m)
else
	platform=$(arch)
fi

ARCH="UNKNOWN"

case "$platform" in
x86_64)
	PACKAGE_NAME="nvim-linux64"
    REPO="neovim/neovim"
	;;
aarch64 | arm64)
	PACKAGE_NAME="nvim-linux64-arm64"
    REPO="free-150/scripts"
	;;
*)
	echo -e "\r\n${tty_red}出错了，不支持的架构${tty_reset}\r\n"
	exit 1
	;;
esac
}

is_neovim_version() {
  neovim_github_api_url="https://api.github.com/repos/$REPO/releases/latest"
  get_version=$(curl -s ${neovim_github_api_url} \
  | grep 'tag_name' \
  | awk -F'"' '{print $4}')
}


download_neovim() {
  is_tmp_dir="/tmp/isneovim/"
  if [ -d "$is_tmp_dir" ]; then
    rm -rf "$is_tmp_dir"
  fi

  if [ -d "/usr/local/nvim" ]; then
    rm -rf "/usr/local/nvim"
  fi
  mkdir -p "$is_tmp_dir"
  wget -P ${is_tmp_dir} ${is_mirror}https://github.com/$REPO/releases/download/${get_version}/${PACKAGE_NAME}.tar.gz
}

is_install() {
    NVIM_FILE="/tmp/isneovim/${PACKAGE_NAME}.tar.gz"
    INSTALL_DIR="/usr/local/nvim"
    tar -xzvf "$NVIM_FILE" -C /tmp/isneovim >/dev/null 2>&1
    mkdir -p "$INSTALL_DIR"
    mv /tmp/isneovim/nvim-linux64/* "$INSTALL_DIR" >/dev/null 2>&1
    chmod +x "$INSTALL_DIR/bin/nvim"
    [ -L /usr/local/bin/nvim ] && rm /usr/local/bin/nvim
    ln -s "$INSTALL_DIR/bin/nvim" /usr/local/bin/nvim
}

ADD_PATH() {
  nvim_path="/etc/profile.d/nvim.sh"
  if [ -f "$nvim_path" ]; then
    rm -rf "$nvim_path"
  fi
  cat <<EOF > "$nvim_path"
export PATH=\$PATH:/usr/local/nvim/bin
EOF

  chmod +x "$nvim_path"
  source "/etc/profile"
  echo "Neovim 安装成功!"
}

ADD_MINI_CONFIG() {
  if [ ! -d ~/.config/nvim ]; then
    mkdir -p ~/.config/nvim   # 创建目录
  fi

  if [ -f ~/.config/nvim/init.lua ]; then
    rm -rf ~/.config/nvim/init.lua
  else
    touch ~/.config/nvim/init.lua  # 创建空的 init.lua 文件
  fi

  cat <<EOF >> ~/.config/nvim/init.lua
-- 设置行号
vim.opt.number = true             -- 显示绝对行号
vim.opt.relativenumber = true     -- 显示相对行号

-- 设置 Tab 缩进
vim.opt.tabstop = 4              -- 一个 tab 键宽度为 4 个空格
vim.opt.shiftwidth = 4           -- 每次缩进使用 4 个空格
vim.opt.expandtab = true         -- 使用空格代替 Tab 键

-- 设置剪贴板
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
    ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
  },
}
EOF
}

start_init () {
  is_platform
  is_neovim_version
  download_neovim
  is_install
  ADD_PATH
  ADD_MINI_CONFIG

}

is_CLI "$@"
start_init
