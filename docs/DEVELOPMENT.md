# XrayMulti 开发文档

本文档介绍 XrayMulti 的构建、开发和贡献指南。

### 本地构建

#### 1. 完整构建（推荐）

```bash
# 构建 Docker 镜像
docker compose build

# 启动容器
docker compose up -d
```

#### 2. 仅编译 Go 程序

```bash
# 使用 Docker 编译（无需本地 Go 环境）
docker run --rm \
  -v "$PWD/core":/app \
  -w /app \
  -e GOPROXY=https://goproxy.cn,direct \
  golang:1.21-alpine \
  go build -o subconverter subconverter.go

# 本地编译（需要 Go 1.21+）
cd core
go build -o subconverter subconverter.go
```

#### 3. 更新 Go 依赖

```bash
# 添加新依赖
cd core
go get <package-name>

# 生成 go.sum（使用 Docker）
docker run --rm \
  -v "$PWD/core":/app \
  -w /app \
  -e GOPROXY=https://goproxy.cn,direct \
  golang:1.21-alpine \
  go mod tidy

# 验证依赖
go mod verify
```

## 相关资源

- [Go 官方文档](https://golang.org/doc/)
- [Xray 配置文档](https://xtls.github.io/config/)
- [Docker 最佳实践](https://docs.docker.com/develop/dev-best-practices/)
- [Alpine Linux 包管理](https://wiki.alpinelinux.org/wiki/Alpine_Linux_package_management)

## 许可证

MIT License - 详见根目录 LICENSE 文件
