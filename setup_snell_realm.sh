#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 检查是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED}错误：此脚本必须以 root 权限运行。${NC}"
   exit 1
fi

# 函数：安装必要的工具
install_deps() {
    local pkgs=("$@")
    local pm=""
    local update_cmd=""
    local install_cmd=""

    if command -v apt-get &> /dev/null; then
        pm="apt-get"
        update_cmd="apt-get update"
        install_cmd="apt-get install -y"
    elif command -v yum &> /dev/null; then
        pm="yum"
        update_cmd="yum makecache fast"
        install_cmd="yum install -y"
    elif command -v dnf &> /dev/null; then
        pm="dnf"
        update_cmd="dnf makecache"
        install_cmd="dnf install -y"
    else
        echo -e "${RED}错误：不支持的包管理器。请手动安装：${pkgs[*]} ${NC}"
        exit 1
    fi

    missing_pkgs=()
    for pkg in "${pkgs[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            # 特殊处理 unzip 命令名和包名可能不同的情况 (如 CentOS)
            if [[ "$pkg" == "unzip" && "$pm" != "apt-get" ]]; then
                 if ! rpm -q unzip &> /dev/null; then
                     missing_pkgs+=("unzip")
                 fi
            elif [[ "$pkg" == "wget" && "$pm" != "apt-get" ]]; then
                 if ! rpm -q wget &> /dev/null; then
                     missing_pkgs+=("wget")
                 fi
            else
                 missing_pkgs+=("$pkg")
            fi
        fi
    done

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo -e "${YELLOW}正在更新包列表并安装缺失的依赖：${missing_pkgs[*]}...${NC}"
        sudo $update_cmd
        sudo $install_cmd "${missing_pkgs[@]}"
        if [ $? -ne 0 ]; then
            echo -e "${RED}错误：依赖安装失败。请手动安装后重试。${NC}"
            exit 1
        fi
    fi
}

# 函数：生成随机端口
generate_port() {
    local port=$(shuf -i 40000-65535 -n 1)
    # 检查端口是否被占用 (简单检查)
    while ss -tuln | grep -q ":$port\b" || [ -z "$port" ]; do
        port=$(shuf -i 40000-65535 -n 1)
    done
    echo "$port"
}

# 函数：生成随机密码 (PSK)
generate_psk() {
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16
}

# 函数：配置落地服务器 (Snell)
setup_landing_server() {
    echo -e "${GREEN}--- 开始配置落地服务器 (Snell v4) ---${NC}"
    install_deps curl # jinqians/snell.sh 需要 curl

    echo -e "${YELLOW}本脚本将使用 jinqians/snell.sh 提供的脚本来安装 Snell 服务。${NC}"
    echo -e "${YELLOW}请仔细阅读该脚本执行过程中的输出。${NC}"
    echo -e "${RED}安装完成后，请务必手动记录下脚本输出的【IP 地址】、【Snell 端口】和【Snell PSK】。${NC}"
    echo -e "${RED}这些信息是下一步配置线路机（Realm）所必需的！${NC}"
    read -p "按 Enter 键继续执行 jinqians/snell.sh 安装脚本..."

    # 执行 jinqians/snell.sh 的安装命令
    bash <(curl -L -s snell.jinqians.com)

    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "\\n${GREEN}jinqians/snell.sh 脚本执行完成。${NC}"
        echo -e "${YELLOW}请确认您已记录下 Snell 的 IP、端口和 PSK。${NC}"
        echo -e "${YELLOW}同时，请确保防火墙已放行 Snell 服务所使用的 TCP 端口。${NC}"
    else
        echo -e "\\n${RED}错误：jinqians/snell.sh 脚本执行失败，退出码: $exit_code。${NC}"
        echo -e "${RED}请检查网络连接或尝试手动执行 'bash <(curl -L -s snell.jinqians.com)' 查看具体错误。${NC}"
        exit 1
    fi

    echo -e "${GREEN}落地服务器 Snell 配置步骤（通过外部脚本）已触发。请根据外部脚本提示操作并记录信息。${NC}"
    echo -e "${GREEN}-----------------------------------${NC}"
}

# 函数：配置线路机 (Realm)
setup_relay_server() {
    echo -e "${GREEN}--- 开始配置线路机 (Realm 转发) ---${NC}"
    install_deps wget bash curl

    local ezrealm_url="https://raw.githubusercontent.com/qqrrooty/EZrealm/main/realm.sh"
    local ezrealm_script="realm.sh"

    # --- 获取用户输入 ---
    local landing_ip
    local snell_port
    local realm_listen_port

    read -p "请输入落地服务器的 IP 地址: " landing_ip
    while [[ -z "$landing_ip" ]]; do
        echo -e "${RED}IP 地址不能为空。${NC}"
        read -p "请输入落地服务器的 IP 地址: " landing_ip
    done

    read -p "请输入落地服务器上 Snell 服务监听的端口: " snell_port
    while [[ ! "$snell_port" =~ ^[0-9]+$ || "$snell_port" -lt 1 || "$snell_port" -gt 65535 ]]; do
        echo -e "${RED}端口号无效，请输入 1-65535 之间的数字。${NC}"
        read -p "请输入落地服务器上 Snell 服务监听的端口: " snell_port
    done

    local default_realm_port=$(generate_port)
    read -p "请输入 Realm 在此线路机上监听的入端口 [默认为 $default_realm_port]: " realm_listen_port
    realm_listen_port=${realm_listen_port:-$default_realm_port}
    while [[ ! "$realm_listen_port" =~ ^[0-9]+$ || "$realm_listen_port" -lt 1 || "$realm_listen_port" -gt 65535 ]]; do
        echo -e "${RED}端口号无效，请输入 1-65535 之间的数字。${NC}"
        read -p "请输入 Realm 在此线路机上监听的入端口 [默认为 $default_realm_port]: " realm_listen_port
        realm_listen_port=${realm_listen_port:-$default_realm_port}
    done


    # --- 下载并执行 EZrealm ---
    echo -e "${YELLOW}正在下载 EZrealm 脚本...${NC}"
    wget -q -O "$ezrealm_script" "$ezrealm_url"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：EZrealm 脚本下载失败。${NC}"
        exit 1
    fi
    chmod +x "$ezrealm_script"

    echo -e "\n${YELLOW}即将运行 EZrealm 脚本。请根据脚本提示进行操作。${NC}"
    echo -e "您需要进行以下主要操作："
    echo -e "1. 如果尚未安装 Realm，请选择 ${GREEN}安装 Realm${NC}。"
    echo -e "2. 选择 ${GREEN}添加转发规则${NC}。"
    echo -e "3. 设置本地监听端口为: ${YELLOW}$realm_listen_port${NC}"
    echo -e "4. 设置远程地址为: ${YELLOW}$landing_ip${NC}"
    echo -e "5. 设置远程端口为: ${YELLOW}$snell_port${NC}"
    echo -e "6. 传输协议保持默认通常即可（一般是 TCP，Snell 基于 TCP）。"
    read -p "按 Enter 键继续运行 EZrealm 脚本..."

    ./"$ezrealm_script"

    # 清理脚本
    # rm -f "$ezrealm_script" # 保留脚本方便后续管理 Realm

    # --- 检查 Realm 监听端口状态 ---
    echo -e "${YELLOW}正在检查 Realm 监听端口 $realm_listen_port 是否已启动...${NC}"
    local realm_retry_count=0
    local realm_max_retries=5
    local realm_check_interval=3 # seconds
    while ! ss -tuln | grep -q ":$realm_listen_port\\b" && [ $realm_retry_count -lt $realm_max_retries ]; do
        echo -e "${YELLOW}端口 $realm_listen_port 尚未监听，等待 $realm_check_interval 秒后重试 ($((realm_retry_count+1))/$realm_max_retries)...${NC}"
        sleep $realm_check_interval
        ((realm_retry_count++))
    done

    if ss -tuln | grep -q ":$realm_listen_port\\b"; then
        echo -e "${GREEN}Realm 监听端口 $realm_listen_port 已成功启动！${NC}"
        echo -e "${YELLOW}(注意：这仅确认端口正在监听，不保证转发规则配置完全正确，请进行连接测试)${NC}"
    else
        echo -e "${RED}错误：Realm 监听端口 $realm_listen_port 未启动或启动失败。${NC}"
        echo -e "${RED}请检查 EZrealm 配置过程或运行 './realm.sh' 查看 Realm 状态。${NC}"
        # 不在此处退出，允许用户查看后续信息
    fi

    echo -e "\n${GREEN}--- Realm 转发配置引导完成 ---${NC}"
    echo -e "请确认您已根据 EZrealm 的提示成功添加了转发规则。"
    echo -e "客户端应连接到此线路机："
    local relay_ip=$(curl -s --connect-timeout 5 https://api.ipify.org || hostname -I | awk '{print $1}')
    echo -e "服务器地址: ${YELLOW}$relay_ip${NC}"
    echo -e "服务器端口: ${YELLOW}$realm_listen_port${NC}"
    echo -e "协议: ${YELLOW}Snell v4${NC}"
    echo -e "密码 (PSK): ${YELLOW}请使用落地服务器上生成的 Snell 密码${NC}"
    echo -e "(如果需要 Obfs，请确保两端配置一致)"
    echo -e "\n${YELLOW}重要提示：请确保防火墙已放行 TCP 端口 $realm_listen_port ${NC}"
    echo -e "${GREEN}-------------------------------${NC}"

}

# --- 主逻辑 ---
echo "请选择要执行的操作："
echo "1) 配置落地服务器 (安装 Snell v4)"
echo "2) 配置线路机 (安装 Realm 并设置转发)"
read -p "请输入选项 [1-2]: " choice

case $choice in
    1)
        setup_landing_server
        ;;
    2)
        setup_relay_server
        ;;
    *)
        echo -e "${RED}无效选项。${NC}"
        exit 1
        ;;
esac

exit 0
