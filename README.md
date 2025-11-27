# XrayMulti

基于 `teddysun/xray` 镜像的 Xray-core 多节点客户端，支持从 Xray Json 订阅自动配置多个入站代理。

## 功能特性

- ✅ **订阅支持**: 自动从 URL 获取和更新 Clash 格式订阅
- ✅ **多入站配置**: 支持配置多个 HTTP/SOCKS 入站端口（JSON 格式）
- ✅ **节点映射**: 每个入站可指定对应的订阅节点名称
- ✅ **定时更新**: 支持自动定时更新订阅并重启 Xray
- ✅ **容器化部署**: 基于 Docker 快速部署
- ✅ **命令行工具**: 提供便捷的管理命令

## 快速开始

### 1. 配置订阅

复制 `app.conf.example` 文件到`app.conf`，设置你的订阅 URL：

```bash
# 订阅URL（必填）
SUBSCRIPTION_URL="https://your-subscription-url.com/sub"

# 订阅更新间隔(秒)，默认24小时
SUBSCRIPTION_UPDATE_INTERVAL=86400

# 订阅文件路径
SUBSCRIPTION_FILE="/opt/xraymulti/config/subscription.json"

# Xray 配置
XRAY_LOG_LEVEL="warning"

# API 配置（用于 Xray API 控制）
# 不要暴露 API 到公网
API_LISTEN="127.0.0.1"  # API 监听地址
API_PORT="8080"          # API 监听端口

# 入站配置 - JSON 格式
# 每个入站可以指定对应的订阅节点名称
INBOUNDS_JSON='[
  {"protocol": "http", "port": 11000, "tag": "proxy1", "name": "香港节点"},
  {"protocol": "socks", "port": 11001, "tag": "proxy2", "name": "美国节点"}
]'
```

**入站配置说明**：
- `protocol`: 协议类型，支持 `http` 或 `socks`
- `port`: 监听端口
- `tag`: 入站标签（唯一标识）
- `name`: 对应订阅 YAML 中的节点名称（完全匹配）

### 2. 配置 Docker Compose

`docker-compose.yml` 已经配置好了，可以根据需要调整端口映射：

```yaml
services:
  xraymulti:
    container_name: xraymulti
    image: kitcoun/xraymulti:latest
    restart: always
    ports:
      # 根据 config/app.conf 中的 INBOUNDS_JSON 配置端口
      - "11000-11010:11000-11010"
    volumes:
      - './config:/opt/xraymulti/config'
      - './logs:/var/log/xraymulti'
```

### 3. 构建并启动

```bash
# 构建镜像
docker compose build

# 启动容器
docker compose up -d

# 查看日志
docker compose logs -f
```

容器启动时会自动：
1. 加载配置文件
2. 设置定时任务（自动更新订阅）
3. 下载并转换订阅配置
4. 启动 Xray 服务

### 测试
```bash
curl -x http://localhost:11000 https://www.google.com
```

## 使用方法

### 使用 xraymulti 命令

提供便捷的命令行工具管理订阅和配置：

```bash
# 查看服务状态
docker exec xraymulti xraymulti status

# 更新订阅（使用配置文件中的URL）
docker exec xraymulti xraymulti update

# 使用指定URL更新订阅
docker exec xraymulti xraymulti update "https://new-subscription-url.com"

# 重新加载配置（不更新订阅）
docker exec xraymulti xraymulti reload

# 查看日志
docker exec xraymulti xraymulti logs

# 查看帮助
docker exec xraymulti xraymulti help
```
### 使用 xray 命令
```bash
# 列出所有入站配置  
docker exec xraymulti xray api lsi  
  
# 只列出标签  
docker exec xraymulti xray api lsi --isOnlyTags=true 

# 查看出站配置    
docker exec xraymulti xray api lso  
```
## 目录结构

```
XrayMulti/
├── config/                    # 配置文件目录（映射到容器）
│   ├── app.conf              # 主配置文件
│   ├── app.conf.example      # 配置示例
│   └── subscription.json      # 订阅文件（自动生成）
├── core/                     # 核心脚本和程序
│   ├── subconverter.go       # Go 转换程序
│   ├── go.mod                # Go 模块定义
│   ├── go.sum                # Go 依赖锁定
│   ├── init.sh               # 初始化脚本
│   ├── sub.sh                # 订阅更新脚本
│   ├── convert.sh            # 配置转换脚本
│   ├── xraymulti.sh          # 主控制脚本
│   └── xraymulti-entrypoint.sh  # Docker 入口点
├── logs/                     # 日志目录（映射到容器）
│   ├── init.log              # 初始化日志
│   ├── sub.log               # 订阅更新日志
│   └── convert.log           # 配置转换日志
├── docs/                     # 文档目录
│   ├── CONFIG.md             # 配置说明
│   └── DEVELOPMENT.md        # 开发文档
├── docker-compose.yml        # Docker Compose 配置
├── Dockerfile.custom         # 自定义 Dockerfile
├── .dockerignore            # Docker 忽略文件
└── README.md                # 本文档
```

## 配置说明

### 订阅配置

支持 Xray Json 格式的订阅

订阅可以是原始 json 或 Base64 编码格式。

### 入站配置

使用 JSON 格式配置多个入站，每个入站可指定对应的节点名称：

```json
[
  {
    "protocol": "http",
    "port": 11000,
    "tag": "proxy1",
    "name": "香港-高速"
  },
  {
    "protocol": "socks",
    "port": 11001,
    "tag": "proxy2",
    "name": "美国-流媒体"
  }
]
```

**字段说明**：
- `protocol`: 协议类型（`http` 或 `socks`）
- `port`: 监听端口
- `tag`: 入站标签（唯一标识）
- `name`: 订阅中的节点名称（完全匹配）

### 路由策略

每个入站通过 `name` 字段精确映射到订阅中的节点：
- 匹配成功：入站直接连接到指定节点
- 匹配失败：使用订阅中的第一个节点（并记录警告）

**示例**：
```bash
# 订阅中有节点：香港-A、香港-B、美国-A
# 配置入站：
#   proxy1 -> "香港-A"  ✓ 匹配成功
#   proxy2 -> "美国-A"  ✓ 匹配成功
#   proxy3 -> "日本-A"  ✗ 未匹配，使用第一个节点
```

## 日志查看

### 在宿主机查看

```bash
# 初始化日志
tail -f logs/init.log

# 订阅更新日志
tail -f logs/sub.log

# 配置转换日志
tail -f logs/convert.log
```

### 在容器内查看

```bash
docker exec xraymulti xraymulti logs
```

## 故障排除

### 订阅更新失败

1. 检查订阅 URL 是否正确
2. 检查网络连接
3. 查看订阅日志：`xraymulti logs` → 选择 2

### 配置转换失败

1. 检查订阅格式是否为 Clash YAML
2. 确认订阅中包含代理节点
3. 查看转换日志：
```bash
docker exec xraymulti cat /var/log/xraymulti/convert.log
```

### 节点名称不匹配

1. 查看所有可用节点名称：
```bash
docker exec xraymulti cat /var/log/xraymulti/convert.log | grep "节点 \["
```
2. 修改 `config/app.conf` 中的 `INBOUNDS_JSON`，使用正确的节点名称
3. 重启容器或手动重新加载：
```bash
docker exec xraymulti xraymulti reload
```

### Xray 无法启动

1. 检查生成的配置文件：
```bash
docker exec xraymulti cat /etc/xray/config.json
```
2. 检查端口是否被占用
3. 查看容器日志：
```bash
docker compose logs xraymulti
```

## 高级配置

### 修改日志级别

编辑 `config/app.conf`:

```bash
XRAY_LOG_LEVEL="debug"  # debug, info, warning, error, none
```

### 修改更新间隔

编辑 `config/app.conf`：

```bash
# 每12小时更新一次
SUBSCRIPTION_UPDATE_INTERVAL=43200

# 每6小时更新一次
SUBSCRIPTION_UPDATE_INTERVAL=21600
```

### 禁用自动更新

删除或注释掉订阅URL：

```bash
# SUBSCRIPTION_URL=""
```

或者设置一个很大的更新间隔：

```bash
SUBSCRIPTION_UPDATE_INTERVAL=31536000  # 1年
```

## 相关链接

- [配置说明文档](docs/CONFIG.md)
- [开发文档](docs/DEVELOPMENT.md)
- [Xray-core 官方文档](https://xtls.github.io/)
- [TeddySun Xray Docker](https://hub.docker.com/r/teddysun/xray)

## 许可证

MIT License

## 致谢

- **teddysun/xray** - Docker 基础镜像
- **Xray-core** - 高性能代理核心
- **Go** - 高性能编程语言
