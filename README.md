# SnellForward
 A script for Snell protocol forwarding using Realm

## 简介

`SnellForward` 是一个 Bash 脚本，旨在简化 Snell v4 协议通过 Realm 进行转发的部署流程。通过在一个"落地服务器"上运行 Snell 服务，并在一个"线路服务器"上使用 Realm 将流量转发至落地服务器，可以实现更灵活的网络代理配置。本脚本旨在自动化大部分安装和配置过程。

## 架构

本方案需要两台服务器：

1.  **落地服务器 (Landing Server):**
    *   直接连接目标网络的服务器。
    *   运行 Snell v4 服务端。
    *   脚本将在此服务器上安装 Snell，配置端口和密码，并设置后台服务。
2.  **线路服务器 (Relay Server):**
    *   作为客户端流量入口的服务器。
    *   运行 Realm，将收到的 Snell 流量转发到落地服务器。
    *   脚本将在此服务器上引导安装 Realm（通过 EZrealm 脚本），并配置转发规则。

客户端最终连接的是 **线路服务器** 的地址和 Realm 监听端口。

## 准备工作

*   **两台服务器:** 一台作为落地服务器，一台作为线路服务器。
    *   推荐使用常见的 Linux 发行版，如 Debian, Ubuntu, CentOS 等（脚本会自动检测 `apt` 或 `yum`/`dnf` 包管理器）。
*   **Root 权限:** 脚本需要在两台服务器上都以 `root` 用户执行。
*   **网络连接:** 服务器需要能够访问互联网以下载所需软件（Snell, Realm 等）。

## 使用方法

**注意**: 脚本需要在 root 权限下运行。

### 1. 下载脚本

在 **两台服务器** 上都执行以下命令下载脚本：

```bash
wget -O setup_snell_realm.sh https://raw.githubusercontent.com/bendusy/SnellForward/main/setup_snell_realm.sh && chmod +x setup_snell_realm.sh
```
或者使用 `curl`:
```bash
curl -Lo setup_snell_realm.sh https://raw.githubusercontent.com/bendusy/SnellForward/main/setup_snell_realm.sh && chmod +x setup_snell_realm.sh
```

### 2. 运行脚本

**重要提示：推荐的操作顺序**

为了顺利完成配置，请按照以下顺序操作：

1.  **首先，在你的【落地服务器】上运行脚本。** 选择 `选项 1` 来安装和配置 Snell 服务端。
2.  **务必记下** 脚本在落地服务器上成功运行后输出的 `服务器 IP 地址`, `Snell 端口`, 和 `Snell PSK`。这些信息在下一步配置线路服务器时至关重要。
3.  **然后，在你的【线路服务器】上运行脚本。** 选择 `选项 2` 来安装 Realm 并配置转发规则。在此过程中，你需要输入上一步记下的落地服务器信息。

---

现在，你可以在相应的服务器上，使用 `root` 权限运行下载好的脚本：

```bash
sudo ./setup_snell_realm.sh
```

脚本会提示你选择要执行的操作：

#### 选项 1: 配置落地服务器 (Snell) - **【第一步，在落地服务器上操作】**

*   在 **落地服务器** 上选择此项。
*   脚本会自动完成：
    *   检测并尝试安装依赖 (`wget`, `unzip`, `systemctl`)。
    *   下载并安装 Snell v4。
    *   生成随机端口和 PSK。
    *   设置 Systemd 服务 (`snell.service`) 并启动。
    *   检查服务状态（带重试）。
*   **重要:** 配置完成后，会显示服务器 IP、Snell 端口、Snell PSK 以及可直接用于 Surge 的配置行。**请务必记下这些信息**，特别是 **IP、端口和 PSK**，**下一步在线路机配置时会用到**。
*   **防火墙:** 确保在 **落地服务器** 的防火墙（如 `ufw`, `firewalld`）中 **放行 TCP 协议的 Snell 端口**。

#### 选项 2: 配置线路机 (Realm) - **【第二步，在线路服务器上操作】**

*   在 **线路服务器** 上选择此项。
*   **前提:** 请确保你已经完成了 **第一步**（在落地服务器上配置 Snell），并且已经记录了落地服务器的 IP 地址和 Snell 端口。
*   你需要根据提示输入之前记录的 **落地服务器的 IP 地址** 和 **Snell 端口**。
*   脚本会推荐一个 Realm 监听端口，你可以接受默认值或自定义。
*   随后，脚本会下载并执行 `EZrealm` 脚本。你需要根据 `EZrealm` 的菜单完成以下步骤：
    1.  如果 Realm 未安装，选择 `安装 Realm`。
    2.  选择 `添加/修改 转发规则`。
    3.  **本地监听端口**: 输入脚本提示的端口（或你自定义的）。
    4.  **远程地址**: 输入 **落地服务器的 IP**。
    5.  **远程端口**: 输入 **落地服务器的 Snell 端口**。
    6.  **传输协议** 通常保持默认（`any` 或 `tcp`）即可。
*   完成后，脚本会检查 Realm 监听端口是否已启动，并显示线路机的 IP 和 Realm 监听端口，这是客户端需要连接的地址和端口。
*   **防火墙:** 确保在 **线路服务器** 的防火墙中 **放行 TCP 协议的 Realm 监听端口**。

## 客户端配置

在你的 Snell 客户端（如 Surge, Stash, Shadowrocket 等）中添加一个新的 Snell 代理配置，填入以下信息：

*   **服务器地址 (Server):** `线路服务器 IP`
*   **端口 (Port):** `Realm 监听端口`
*   **协议 (Protocol):** `Snell`
*   **密码 (PSK):** `Snell 密码 (PSK)` (来自落地服务器)
*   **版本 (Version):** `4`
*   **Obfs (混淆):**
    *   **默认不启用:** 如果你在落地服务器的 Snell 配置 (`/etc/snell/snell-server.conf`) 中没有启用 `obfs`，客户端也保持 `off` 或不填。
    *   **手动启用:** 如果你在落地服务器上手动配置了 `obfs = http` 或 `obfs = tls`，客户端需要配置对应的 Obfs 类型和参数。
    *   **高级混淆 (如 ShadowTLS):** 如果你需要更强的抗封锁能力，可以考虑在 Snell 配置中加入 `shadow-tls` 等参数，并重启 Snell 服务。相应地，在客户端配置中添加 `shadow-tls-password`, `shadow-tls-sni` 等参数。这需要手动操作，脚本不直接支持。
*   **建议参数:** `reuse=true`, `tfo=true` (如果网络和客户端支持)

## 注意事项

*   脚本会自动尝试安装 `wget`, `unzip`, `curl`, `systemctl` 等依赖。如果自动安装失败，请根据提示手动安装。
*   线路机的 Realm 配置依赖于第三方脚本 `EZrealm`。请留意其输出信息。本脚本运行结束后，`realm.sh` (EZrealm 脚本) 会保留在当前目录，方便你后续管理 Realm 规则 (运行 `sudo ./realm.sh` 即可)。
*   安全性：生成的 PSK 强度有限，建议考虑定期更换。请妥善保管 PSK。
*   如果 Snell 服务启动失败，可以使用 `sudo journalctl -u snell -f` 查看日志。
*   如果 Realm 转发不工作，请检查：
    *   两台服务器的防火墙端口是否都已正确放行 (TCP)。
    *   线路机上 Realm 的配置是否正确指向了落地机的 Snell IP 和端口 (可通过 `sudo ./realm.sh` 查看规则)。
    *   落地机上的 Snell 服务是否正常运行 (`sudo systemctl status snell`)。
    *   Realm 监听端口是否在监听 (`ss -tuln | grep <realm_listen_port>`)。

## 卸载

*   **Snell (落地服务器)**:
    ```bash
    sudo systemctl stop snell
    sudo systemctl disable snell
    sudo rm /etc/systemd/system/snell.service
    sudo systemctl daemon-reload
    sudo rm /usr/local/bin/snell-server
    sudo rm -rf /etc/snell
    echo "Snell 已卸载。防火墙规则可能需要手动移除。"
    ```
*   **Realm (线路机)**:
    运行 `sudo ./realm.sh` 并根据 `EZrealm` 的菜单选择卸载选项。
    ```bash
    # 清理 EZrealm 脚本
    # rm ./realm.sh 
    echo "Realm 已通过 EZrealm 卸载。防火墙规则可能需要手动移除。"
    ```

## 致谢 (Acknowledgements)

本脚本在实现落地服务器 Snell 安装部分，参考并推荐使用了来自 [jinqians/snell.sh](https://github.com/jinqians/snell.sh) 的安装脚本，以提高安装的稳定性和易用性。特此感谢。

## License

[MIT](/LICENSE)
