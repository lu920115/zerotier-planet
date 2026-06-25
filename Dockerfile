# ============================================================
# zerotier-planet v1.16.2.2
# 基于 lu920115/zerotier-planet:v1.16.2.1
# 新增：从 ZeroTierOne 源码编译 mkworld，支持生成真正的自建 planet
# 新增：从 ZeroTierOne 源码编译 zerotier-one，启用 UPnP/NAT-PMP 支持以使用 tertiaryPort
# ============================================================

# -------- 阶段 1：编译 mkworld --------
FROM --platform=linux/amd64 alpine:3.18 AS builder

RUN apk update \
    && apk add --no-cache git g++ make linux-headers ca-certificates

# 克隆 ZeroTierOne 源码
# mkworld 与 zerotier-one 主版本解耦，1.14.2 的 mkworld 可兼容 1.16.2
RUN git clone --depth 1 --branch 1.14.2 https://github.com/zerotier/ZeroTierOne.git /zt-src

WORKDIR /zt-src/attic/world
COPY mkworld_custom.cpp ./mkworld.cpp
# 使用静态编译，避免最终 Debian 镜像缺少 musl 库
RUN sed -i 's/-g -o mkworld/-static -g -o mkworld/' build.sh \
    && sh build.sh \
    && chmod +x mkworld \
    && ls -la /zt-src/attic/world/mkworld

# -------- 阶段 2：编译带 UPnP 支持的 zerotier-one --------
FROM --platform=linux/amd64 debian:12 AS zt-builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential git libssl-dev libminiupnpc-dev libnatpmp-dev ca-certificates curl pkg-config \
    && rm -rf /var/lib/apt/lists/* \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

RUN git clone --depth 1 --branch 1.16.2 https://github.com/zerotier/ZeroTierOne.git /zt-src

WORKDIR /zt-src
RUN make -j$(nproc) ZT_USE_MINIUPNPC=1 ZT_NONFREE=1 \
    && ls -la zerotier-one \
    && ./zerotier-one -v

# -------- 阶段 3：最终镜像 --------
FROM lu920115/zerotier-planet:v1.16.2.1

LABEL org.opencontainers.image.title="zerotier-planet"
LABEL org.opencontainers.image.description="ZeroTier Planet Server with CVE fixes, support real planet and moon generation, and tertiaryPort"
LABEL org.opencontainers.image.version="v1.16.2.2"

# 安装 UPnP/NAT-PMP 运行时库
RUN apt-get update \
    && apt-get install -y --no-install-recommends libminiupnpc17 libnatpmp1 \
    && rm -rf /var/lib/apt/lists/*

# 复制修改后的启动脚本
COPY start_zt1.sh /start_zt1.sh
COPY start_ztncui.sh /start_ztncui.sh
COPY start_ztplaserv.sh /start_ztplaserv.sh
COPY supervisord.conf /etc/supervisord.conf

# 复制编译好的 mkworld 工具
COPY --from=builder /zt-src/attic/world/mkworld /usr/local/bin/mkworld

# 复制编译好的 zerotier-one（启用 UPnP/NAT-PMP 支持）
COPY --from=zt-builder /zt-src/zerotier-one /usr/sbin/zerotier-one

# 确保可执行
RUN chmod +x /start_zt1.sh /start_ztncui.sh /start_ztplaserv.sh /usr/local/bin/mkworld /usr/sbin/zerotier-one

EXPOSE 9993/udp 9993/tcp 29993/udp 39993/udp 23180/tcp 23000/tcp

ENTRYPOINT ["/usr/bin/supervisord"]
CMD ["-c", "/etc/supervisord.conf"]
