# XrayMulti

基于 `teddysun/xray` 镜像的 Xray-core 多节点客户端，支持从 Xray Json 订阅自动配置多个入站代理。

## 功能特性

- ✅ **订阅支持**: 自动从 URL 获取和更新订阅
- ✅ **多入站配置**: 支持配置多个 HTTP/SOCKS 入站端口（JSON 格式）
- ✅ **节点映射**: 每个入站可指定对应的订阅节点名称
- ✅ **定时更新**: 支持自动定时更新订阅并重启 Xray
- ✅ **容器化部署**: 基于 Docker 快速部署
- ✅ **命令行工具**: 提供便捷的管理命令

## 快速开始

### 1. 配置订阅

复制 `app.conf.example` 文件到`app.conf`，设置你的订阅 URL：

**入站配置说明**：
- `protocol`: 协议类型，支持 `http` 或 `socks`
- `port`: 监听端口
- `tag`: 入站标签（唯一标识）
- `name`: 对应订阅中的节点名称（完全匹配）

### 2. 配置 Docker Compose

根据需要调整端口映射：

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
