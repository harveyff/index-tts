# 使用 devel 版本以支持编译 C++/CUDA 扩展（BigVGAN 等需要）
FROM pytorch/pytorch:2.8.0-cuda12.8-cudnn9-devel

ENV DEBIAN_FRONTEND=noninteractive \
    GRADIO_SERVER_NAME=0.0.0.0 \
    UV_SYSTEM_PYTHON=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 1. 系统依赖（包括编译工具）
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    git-lfs \
    wget \
    curl \
    bc \
    build-essential \
    && git lfs install \
    && rm -rf /var/lib/apt/lists/*

# 2. 安装 uv（官方推荐的依赖管理工具）
RUN pip install --no-cache-dir --upgrade pip setuptools wheel "uv>=0.4"

# 3. 拷贝项目代码（包含 pyproject.toml、uv.lock、webui.py 等）
COPY . .

# 4. 用 uv 同步依赖（只装 webui 所需的 extra，避免装 deepspeed 之类）
#   如果你想要所有额外特性，可以改成：uv sync --all-extras
#   注意：uv sync 会根据 pyproject.toml 安装正确的 PyTorch 版本（2.8.*）
RUN uv sync --extra webui

# 5. 确保必要的目录存在
RUN mkdir -p checkpoints outputs/tasks prompts

# 6. 暴露 WebUI 端口
EXPOSE 7860

# 7. 用 uv 运行 webui.py（自动启用 .venv 环境）
#    注意：模型文件需要单独下载到 checkpoints 目录
#    可以通过 volume 挂载或使用 huggingface-cli/modelscope 下载
CMD ["uv", "run", "webui.py", "--host", "0.0.0.0", "--port", "7860"]

