# Docker 部署指南

本文档说明如何使用 Docker 部署 IndexTTS2。

## 前置要求

- Docker 和 Docker Compose（可选）
- NVIDIA Docker runtime（nvidia-docker2）用于 GPU 支持
- 至少 10GB 可用磁盘空间

## 构建镜像

```bash
docker build -t indextts:latest .
```

## 下载模型文件

模型文件需要单独下载。有两种方式：

### 方式 1：使用 HuggingFace CLI（推荐）

```bash
# 安装 huggingface-cli
pip install huggingface-hub

# 下载模型
huggingface-cli download IndexTeam/IndexTTS-2 --local-dir=./checkpoints
```

### 方式 2：使用 ModelScope

```bash
# 安装 modelscope
pip install modelscope

# 下载模型
modelscope download --model IndexTeam/IndexTTS-2 --local_dir ./checkpoints
```

## 运行容器

### 基本运行（GPU）

```bash
docker run -d \
  --name indextts \
  --gpus all \
  -p 7860:7860 \
  -v $(pwd)/checkpoints:/app/checkpoints \
  -v $(pwd)/outputs:/app/outputs \
  indextts:latest
```

### 使用 Docker Compose（推荐）

创建 `docker-compose.yml`：

```yaml
version: '3.8'

services:
  indextts:
    build: .
    container_name: indextts
    ports:
      - "7860:7860"
    volumes:
      - ./checkpoints:/app/checkpoints
      - ./outputs:/app/outputs
      - ./prompts:/app/prompts
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    environment:
      - GRADIO_SERVER_NAME=0.0.0.0
    restart: unless-stopped
```

然后运行：

```bash
docker-compose up -d
```

## 访问 Web UI

容器启动后，访问：http://localhost:7860

## 注意事项

1. **模型文件**：确保 `checkpoints` 目录包含以下必需文件：
   - `bpe.model`
   - `gpt.pth`
   - `config.yaml`
   - `s2mel.pth`
   - `wav2vec2bert_stats.pt`

2. **GPU 支持**：确保已安装 NVIDIA Docker runtime。检查：
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu22.04 nvidia-smi
   ```

3. **内存要求**：建议至少 8GB GPU 内存用于推理。

4. **端口映射**：默认端口是 7860，可以通过修改 `docker-compose.yml` 或 `docker run` 命令更改。

5. **数据持久化**：使用 volume 挂载 `checkpoints`、`outputs` 和 `prompts` 目录以持久化数据。

## 故障排除

### 容器无法启动

检查日志：
```bash
docker logs indextts
```

### GPU 不可用

确保：
- 已安装 nvidia-docker2
- Docker daemon 配置了 GPU 支持
- 容器使用 `--gpus all` 标志

### 模型文件缺失

确保模型文件已下载到 `checkpoints` 目录，并且已正确挂载到容器中。

