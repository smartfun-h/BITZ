#!/bin/bash

# 优化后的脚本，提供菜单选择安装环境、配置钱包或开始挖矿
# 支持 Linux 和 macOS，交互式钱包创建，适配 Docker
# 第一步检查 screen 和 expect，第三步运行 bitz collect 并自动进入 screen
# 增加资金确认和版本检查，更新菜单提示

# 设置脚本在遇到错误时退出，并禁止未定义变量
set -e
set -u

# 函数：检查命令是否存在
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "错误：$1 未找到，请确保环境正确"
        exit 1
    fi
}

# 步骤 1：安装环境
install_environment() {
    echo "步骤 1: 安装环境"

    # 判断操作系统
    OS_TYPE=$(uname -s)

    if [ "$OS_TYPE" = "Linux" ]; then
        echo "检测到 Linux 系统"

        # 检查 /etc/resolv.conf 是否可写
        if [ -w /etc/resolv.conf ]; then
            echo "配置 DNS..."
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
            echo "nameserver 8.8.4.4" >> /etc/resolv.conf
        else
            echo "警告：/etc/resolv.conf 不可写，跳过 DNS 配置"
        fi

        # 更新包
        echo "更新包..."
        apt update

        # 检查并安装 curl、screen 和 expect
        echo "检查并安装 curl、screen 和 expect..."
        if ! command -v curl >/dev/null 2>&1; then
            echo "curl 未安装，开始安装..."
            apt install -y curl
        else
            echo "curl 已安装，跳过安装"
        fi

        if ! command -v screen >/dev/null 2>&1; then
            echo "screen 未安装，开始安装..."
            apt install -y screen
        else
            echo "screen 已安装，跳过安装"
        fi

        if ! command -v expect >/dev/null 2>&1; then
            echo "expect 未安装，开始安装..."
            apt install -y expect
        else
            echo "expect 已安装，跳过安装"
        fi

    elif [ "$OS_TYPE" = "Darwin" ]; then
        echo "检测到 macOS 系统"

        # 检查并安装 Homebrew
        if ! command -v brew >/dev/null 2>&1; then
            echo "安装 Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/opt/homebrew/bin/brew shellenv)" || eval "$(/usr/local/bin/brew shellenv)"
        fi

        # 检查并安装 curl、screen 和 expect
        echo "检查并安装 curl、screen 和 expect..."
        if ! command -v curl >/dev/null 2>&1; then
            echo "curl 未安装，开始安装..."
            brew install curl
        else
            echo "curl 已安装，跳过安装"
        fi

        if ! command -v screen >/dev/null 2>&1; then
            echo "screen 未安装，开始安装..."
            brew install screen
        else
            echo "screen 已安装，跳过安装"
        fi

        if ! command -v expect >/dev/null 2>&1; then
            echo "expect 未安装，开始安装..."
            brew install expect
        else
            echo "expect 已安装，跳过安装"
        fi

        echo "注意：macOS DNS 需手动配置（如需 8.8.8.8 和 8.8.4.4，请在系统偏好设置中调整）"

    else
        echo "错误：不支持的操作系统：$OS_TYPE"
        exit 1
    fi

    # 安装 Rust
    echo "安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    check_command rustc
    echo "Rust 版本：$(rustc --version)"

    # 安装 Solana
    echo "安装 Solana..."
    curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev | bash

    # 设置 Solana 路径
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    check_command solana-keygen
    echo "Solana 版本：$(solana --version)"

    # 安装 bitz
    echo "安装 bitz..."
    cargo install bitz
    check_command bitz

    echo "环境安装完成！"
}

# 步骤 2：配置钱包
configure_wallet() {
    echo "步骤 2: 配置钱包"

    # 确保 Solana 配置目录存在
    SOLANA_CONFIG_DIR="$HOME/.config/solana"
    mkdir -p "$SOLANA_CONFIG_DIR"

    # 交互式创建钱包
    echo "创建 Solana 钱包（请按提示操作，可能需要确认助记词）..."
    solana-keygen new

    # 显示钱包位置
    echo "钱包已生成，文件位于 $SOLANA_CONFIG_DIR/id.json"
    echo "请备份该文件，或使用 'solana-keygen pubkey' 查看公钥"
    echo "⚠️ 请妥善保存助记词并导入 Backpack 钱包"

    # 配置 Solana 主网
    echo "配置 Solana 主网..."
    solana config set --url https://mainnetbeta-rpc.eclipse.xyz/

    echo "钱包配置完成！"
}

# 步骤 3：开始挖矿
start_mining() {
    echo "步骤 3: 开始挖矿"

    # 确保 bitz 存在
    check_command bitz

    # 提示资金确认
    read -p "是否已向该钱包的 Eclipse 网络转入 0.005 ETH？[Y/n]: " confirm
    confirm=${confirm:-y}

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        # 检查 screen 会话并清理
        if screen -ls | grep -q "eclipse"; then
            echo "清理现有的 eclipse screen 会话..."
            screen -S eclipse -X quit
        fi

        # 启动 screen 会话并自动进入
        echo "启动 screen 会话 'eclipse' 并运行 bitz collect..."
        echo "你将进入 screen 会话，查看 bitz collect 输出"
        echo "退出会话：按 Ctrl+A, D（分离）；终止挖矿：按 Ctrl+C"
        screen -S eclipse bash -c "bitz collect; exec bash"

        echo "已退出 screen 会话 'eclipse'"
        echo "挖矿仍在后台运行，使用 'screen -r eclipse' 重新进入"
    else
        echo "❌ 已取消挖矿操作"
    fi
}

# 显示菜单
show_menu() {
    clear
    echo "===== Solana 环境配置与挖矿菜单 ====="
    echo "1. 安装环境"
    echo "2. 配置钱包Solana"
    echo "3. 开始挖矿"
    echo "4. 退出"
    echo "===================================="
    echo -n "请输入选项 (1-4): "
}

# 主循环
echo "脚本启动"
while true; do
    show_menu
    read choice

    case "$choice" in
        1)
            install_environment
            echo "安装环境完成，按 Enter 返回菜单"
            read -r
            ;;
        2)
            configure_wallet
            echo "配置钱包完成，按 Enter 返回菜单"
            read -r
            ;;
        3)
            start_mining
            echo "开始挖矿完成，按 Enter 返回菜单"
            read -r
            ;;
        4)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效选项，请输入 1-4"
            read -r
            ;;
    esac
done
