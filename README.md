# zerotier-planet v1.16.2.2

基于 `lu920115/zerotier-planet:v1.16.2.1`，新增 `mkworld` 源码编译和真正的 planet/moon 生成功能，并修复了多端口支持。

## 主要改进

| 功能 | v1.16.2.1 | v1.16.2.2 |
|------|-----------|-----------|
| ZeroTier One 版本 | 1.16.2 | 1.16.2 |
| mkworld 来源 | 无 | 从 ZeroTierOne 源码编译 |
| 生成真正 planet | ❌ | ✅ |
| 自动生成 moon | ❌ | ✅ |
| 同时提供 planet + moon 下载 | ❌ | ✅ |
| 支持 DDNS 域名 | ❌ | ✅ |
| 支持 tertiaryPort（39993） | ❌ | ✅ |
| moon 文件正确签名 | ❌ | ✅ |

## 文件说明

| 文件 | 说明 |
|------|------|
| `Dockerfile` | 多阶段构建，从源码编译 zerotier-one、mkworld |
| `mkworld_custom.cpp` | mkworld 源码补丁 |
| `start_zt1.sh` | 生成 moon/planet 并启动 zerotier-one |
| `start_ztncui.sh` | 启动 ztncui Web 管理界面 |
| `start_ztplaserv.sh` | 提供 planet/moon 文件 HTTP 下载 |
| `supervisord.conf` | 进程管理配置 |
| `test_v1.16.2.2.sh` | 本地测试脚本 |

## 环境变量

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `MYADDR` | ✅ | 无 | 公网 IP 或 DDNS 域名。**强烈推荐用纯 IPv4 DDNS 域名** |
| `ZTNCUI_PASSWD` | ❌ | `password` | ztncui 管理密码 |
| `GENERATE_PLANET` | ❌ | `true` | 是否生成真正的 planet 文件 |
| `HTTP_PORT` | ❌ | `3000` | ztncui HTTP 端口 |
| `HTTP_ALL_INTERFACES` | ❌ | `yes` | 是否监听所有接口。设置后 ztncui 只监听 HTTP_PORT，不启用 HTTPS |

## 使用方式

```yaml
services:
  zerotier-planet:
    image: lu920115/zerotier-planet:v1.16.2.2
    container_name: zerotier-planet
    restart: unless-stopped
    network_mode: host
    environment:
      - MYADDR=example.com
      - HTTP_PORT=23000
      - HTTP_ALL_INTERFACES=yes
      - ZTNCUI_PASSWD=your_password
    volumes:
      - ./zerotier-one:/var/lib/zerotier-one
      - ./ztncui/etc:/opt/key-networks/ztncui/etc
    cap_add:
      - NET_ADMIN
```

> 建议使用 `network_mode: host`，避免 Docker NAT 改写端口导致 ZeroTier 连接异常。

## 端口说明

| 端口 | 协议 | 用途 | 是否必须放行 |
|------|------|------|-------------|
| 9993/udp | UDP | ZeroTier 主通信端口 | ✅ 必须 |
| 29993/udp | UDP | secondary 端口 | 强烈建议 |
| 39993/udp | UDP | tertiary 端口 | 强烈建议 |
| 23000/tcp | TCP | ztncui Web 管理界面 | 是 |
| 23180/tcp | TCP | planet/moon 文件下载 | 是 |

> 本镜像默认 ztncui 为 23000，ztplaserv 为 23180。如需修改，见下方【端口修改】章节。

## 强烈推荐：Moon + DDNS 域名方案

对于**动态公网 IP**环境，这是最优方案：

1. 配置一个**只返回 A 记录**的 DDNS 域名，如 `zt.example.com`
2. 客户端安装 moon 文件
3. IP 变化后，DDNS 更新，客户端自动解析新 IP
4. **无需重新安装 moon 文件**

### 为什么不推荐 Planet 替换方案？

- planet 文件里**只能写 IP 地址，不能写域名**
- 如果公网 IP 变化，必须**重新生成 planet 文件并重新分发到所有客户端**
- 维护量大，容易遗漏设备

### 能不能把官方 planet 节点也写进自建 planet？

**不能。** planet 文件需要签名验证，你没有官方私钥，混进去会导致客户端验证失败。

## 客户端接入

### 方案 A：安装 Moon（推荐动态 IP）

```bash
# 下载 moon 文件
wget https://example.com:23180/000000xxxxxxxxxx.moon

# 安装
mkdir -p /var/lib/zerotier-one/moons.d
cp 000000xxxxxxxxxx.moon /var/lib/zerotier-one/moons.d/
systemctl restart zerotier-one

# 验证
zerotier-cli listmoons
```

### 方案 B：替换 Planet（仅固定 IP）

```bash
# 下载 planet 文件
wget https://example.com:23180/planet

# 替换
systemctl stop zerotier-one
cp planet /var/lib/zerotier-one/planet
systemctl start zerotier-one
```

## 端口修改

### 修改 ztncui HTTP 端口

修改 compose 里的 `HTTP_PORT` 环境变量即可。例如改成 23000：

```yaml
environment:
  - HTTP_PORT=23000
  - HTTP_ALL_INTERFACES=yes
```

> 注意：`HTTP_ALL_INTERFACES=yes` 时，ztncui 只监听 HTTP_PORT，不启用默认的 3443 HTTPS 端口。如果要启用 3443 HTTPS，需要去掉 `HTTP_ALL_INTERFACES`，并确保证书有效。

### 修改 ztplaserv 下载端口

ztplaserv 的端口在 `start_ztplaserv.sh` 里硬编码。修改后需要重新构建镜像。

例如从 3180 改成 23180：

```bash
# 修改 start_ztplaserv.sh
sed -i 's/http.server 3180/http.server 23180/' start_ztplaserv.sh

# 重新构建
docker build --platform linux/amd64 -t lu920115/zerotier-planet:v1.16.2.2 .
```

## 构建

```bash
docker build --platform linux/amd64 -t lu920115/zerotier-planet:v1.16.2.2 .
```

构建参数说明：

- `ZT_USE_MINIUPNPC=1`：启用 UPnP/NAT-PMP 支持，这是 `tertiaryPort` 生效的前提
- `ZT_NONFREE=1`：启用 nonfree controller 功能，ztncui 才能正常管理网络

## 测试

```bash
./test_v1.16.2.2.sh
```

## 动态 IP 维护 checklist

- [ ] DDNS 域名只配置 A 记录（IPv4）
- [ ] 路由器放行上述 UDP 端口
- [ ] 路由器端口转发到运行容器的设备（外网端口 = 内网端口）
- [ ] 客户端安装 moon 文件而非替换 planet
- [ ] 定期备份 `./zerotier-one` 卷（包含 identity 和签名密钥）

## 常见坑与解决方案

### 1. tertiaryPort（39993）不监听

**现象**：`local.conf` 里配置了 `tertiaryPort: 39993`，但 netstat 看不到 39993。

**原因**：
- zerotier-one 二进制没有编译 UPnP 支持（`ZT_USE_MINIUPNPC`）
- 或 `portMappingEnabled` 为 false

**解决**：

```json
{
  "settings": {
    "primaryPort": 9993,
    "secondaryPort": 29993,
    "tertiaryPort": 39993,
    "allowSecondaryPortRelay": true,
    "portMappingEnabled": true
  }
}
```

并确保镜像编译时加了 `ZT_USE_MINIUPNPC=1`。

### 2. ztncui Networks 页面 404

**现象**：ztncui 能登录，但 Networks 页面报 `HTTPError: Response code 404`。

**原因**：zerotier-one 没有编译 nonfree controller 功能（`ZT_NONFREE=1`）。

**解决**：构建镜像时加上 `ZT_NONFREE=1`。

### 3. 客户端更新 moon 文件后 OFFLINE

**现象**：下载新的 moon 文件放到客户端后，设备显示 OFFLINE。

**原因**：旧的 `start_zt1.sh` 直接手写 `moon.json`，生成的 moon 文件 `updatesMustBeSignedBy` 全为 0，部分客户端拒绝接受。

**解决**：

`start_zt1.sh` 必须使用 `zerotier-idtool initmoon identity.public` 生成带 `signingKey` 的模板，再修改 `stableEndpoints`，最后 `genmoon`。

### 4. 路由器端口转发不能改端口

**现象**：把外网 39993 转发到内网 29993，ZeroTier 客户端连不上。

**原因**：ZeroTier 对源端口一致性有要求，NAT 改写目标端口后，回复包的源端口不一致，客户端会拒绝。

**解决**：外网端口必须等于内网端口：

| 外网端口 | 内网端口 |
|---------|---------|
| 9993 | 9993 |
| 29993 | 29993 |
| 39993 | 39993 |

### 5. IPv6 通信规则源端口不能填

**现象**：配置了 IPv6 通信规则，但外网 IPv6 测试还是 filtered。

**原因**：源端口填了 `9993` 等具体端口。ZeroTier 客户端源端口是随机的临时端口。

**解决**：
- 源端口留空
- 目标端口填 `9993 29993 39993`
- 协议选 UDP
- 源区域 `wan` + `wan6`，目标区域 `lan`

### 6. 移动宽带/大内网设备不上线

**现象**：移动宽带路由器或手机 4G/5G 下的 ZeroTier 客户端不上线。

**原因**：移动宽带 NAT 严格，无法直接打洞。

**解决**：
- 在这些设备上安装 moon 文件
- 确保网络中有公网 IP 节点在线（如 aliyunvps）作为 relay
- 放行 relay 节点的 9993/udp 和 secondaryPort

## 手机客户端说明

- **Android**：官方 ZeroTier App 不支持 moon/planet 自定义，建议使用 **ZeroTier-Fix**
- **iOS**：官方 App 同样受限，一般需要 TestFlight 版本或越狱
- **替代方案**：手机用官方 App 加入 Network ID，通过固定在线节点（如 VPS）中转访问

## 端口转发示例（iStoreOS）

| 规则名 | 来源 | 目标 |
|--------|------|------|
| zerotier-planet9993 | wan:9993/udp | 192.168.*.*:9993/udp |
| zerotier-planet29993 | wan:29993/udp | 192.168.*.*:29993/udp |
| zerotier-planet39993 | wan:39993/udp | 192.168.*.*:39993/udp |
| ztncui-web | wan:23000/tcp | 192.168.*.*:23000/tcp |
| ztplaserv-download | wan:23180/tcp | 192.168.*.*:23180/tcp |

## 通信规则示例（IPv6）

| 字段 | 填写 |
|------|------|
| 名称 | `allow-zerotier-ipv6` |
| 协议 | `UDP` |
| 源区域 | `wan` + `wan6` |
| 源端口 | 留空 |
| 目标区域 | `lan` |
| 目标地址 | 留空 |
| 目标端口 | `9993 29993 39993` |
| 动作 | `接受` |

## 版本历史

- **v1.16.2.2**：修复 moon 签名、启用 tertiaryPort、ztplaserv 端口改为 23180、ztncui 默认 23000
- **v1.16.2.1**：基础 planet/moon 生成
