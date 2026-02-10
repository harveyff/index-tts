# ARM64 (aarch64) + NVIDIA GB10 部署指南

## 硬件环境确认

根据你的系统信息：
- **架构**: aarch64 (ARM64)
- **GPU**: NVIDIA GB10 (Grace Blackwell)
- **驱动版本**: 590.44.01
- **CUDA 版本**: 13.1（驱动支持）
- **问题**: `nvcc: command not found`（CUDA Toolkit 未安装）

## CUDA Toolkit 安装说明

### ⚠️ 重要：容器化部署 vs 直接部署

**对于 Kubernetes/Docker 容器化部署**：
- ✅ **CUDA Toolkit 在容器镜像内**（通过 Dockerfile.arm64 安装）
- ✅ **宿主机只需要 NVIDIA 驱动**（nvidia-smi）
- ❌ **不需要在宿主机安装 CUDA Toolkit**

**对于直接在宿主机运行**（非容器化）：
- 需要在宿主机安装 CUDA Toolkit（见下面的方法 1）

### 方法 1：在宿主机安装 CUDA Toolkit（仅用于非容器化部署）

如果**不在容器中运行**，需要在宿主机安装：

```bash
# 1. 添加 NVIDIA CUDA 仓库（ARM64/SBSA）
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/sbsa/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# 2. 安装 CUDA Toolkit（选择与驱动兼容的版本）
# 注意：CUDA 13.1 可能还没有 ARM64 版本，建议使用 12.8
sudo apt-get install -y cuda-toolkit-12-8

# 3. 设置环境变量
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# 4. 验证安装
nvcc --version
```

### 方法 2：在 Docker 容器内安装（推荐，用于 Kubernetes 部署）

**Dockerfile.arm64 已包含 CUDA Toolkit 安装**，构建镜像时会自动安装。

对于 Kubernetes 部署，请参考 `K8S_DEPLOYMENT.md`。

## PyTorch ARM64 CUDA 支持

### 问题

PyTorch 官方**主要提供 x86_64 架构的 CUDA 预编译包**。ARM64 CUDA 支持有限，可能需要：

1. **使用第三方构建**：某些社区或厂商可能提供 ARM64 CUDA 版本的 PyTorch
2. **从源码编译**：复杂且耗时
3. **使用 CPU 版本**：不支持 GPU 加速（不推荐）

### 解决方案

#### 方案 A：检查是否有 ARM64 CUDA 版本的 PyTorch

```bash
# 检查 PyPI 上是否有 ARM64 CUDA 版本的 PyTorch
pip index versions torch --index-url https://download.pytorch.org/whl/cu128

# 或者尝试安装（可能会失败）
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu128
```

#### 方案 B：使用 NVIDIA 提供的 PyTorch（如果有）

NVIDIA 可能为 Grace Blackwell 提供优化的 PyTorch 版本，检查：
- NVIDIA NGC (NVIDIA GPU Cloud) 容器
- NVIDIA 官方文档

#### 方案 C：修改项目以使用 CPU 版本（不推荐，性能差）

如果无法获得 ARM64 CUDA 版本的 PyTorch，可以修改 `pyproject.toml`：

```toml
# 注释掉 CUDA 相关的配置
# torch = [
#   { index = "pytorch-cuda", marker = "sys_platform == 'linux' or sys_platform == 'win32'" },
# ]
```

然后使用 CPU 版本（性能会大幅下降）。

## Docker 部署步骤

### 1. 构建镜像

```bash
# 使用 ARM64 Dockerfile
docker build -t indextts:arm64 -f Dockerfile.arm64 .
```

### 2. 运行容器

```bash
docker run -d \
  --name indextts \
  --gpus all \
  -p 7860:7860 \
  -v $(pwd)/checkpoints:/app/checkpoints \
  -v $(pwd)/outputs:/app/outputs \
  -v $(pwd)/prompts:/app/prompts \
  # 如果宿主机已安装 CUDA Toolkit，可以挂载
  -v /usr/local/cuda:/usr/local/cuda \
  indextts:arm64
```

### 3. 验证 GPU 可用性

```bash
# 进入容器
docker exec -it indextts bash

# 检查 CUDA
nvcc --version
nvidia-smi

# 检查 PyTorch CUDA
python3 -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"
```

## 故障排除

### 问题 1: nvcc 命令不存在

**原因**: CUDA Toolkit 未安装或未在 PATH 中

**解决**:
```bash
# 在宿主机安装 CUDA Toolkit（见前置步骤）
# 或在 Dockerfile 中安装（已包含）
# 或通过 volume 挂载宿主机的 CUDA
```

### 问题 2: PyTorch CUDA 不可用

**原因**: PyTorch 没有 ARM64 CUDA 版本

**解决**:
1. 检查是否有第三方构建的 ARM64 CUDA PyTorch
2. 联系 NVIDIA 获取 Grace Blackwell 优化的 PyTorch
3. 考虑从源码编译 PyTorch（复杂）

### 问题 3: CUDA 扩展编译失败

**原因**: BigVGAN 的 CUDA 扩展需要编译，ARM64 支持可能有限

**解决**:
```bash
# 检查 CUDA 架构兼容性
nvidia-smi --query-gpu=compute_cap --format=csv

# GB10 的 compute capability 应该是 10.0 或更高
# 可能需要修改 CUDA 编译标志
```

### 问题 4: 依赖安装失败

**原因**: 某些依赖可能没有 ARM64 版本

**解决**:
```bash
# 检查具体哪个包失败
uv sync --extra webui -v

# 可能需要手动安装或使用替代包
```

## 重要提示

1. **ARM64 CUDA 支持是实验性的**：IndexTTS 项目主要针对 x86_64 架构开发和测试
2. **性能可能受影响**：即使能运行，ARM64 版本的性能可能不如 x86_64
3. **建议联系 NVIDIA**：NVIDIA Grace Blackwell 是较新的架构，建议联系 NVIDIA 获取：
   - ARM64 CUDA Toolkit 的完整支持
   - ARM64 PyTorch 的优化版本
   - 针对 GB10 的最佳实践

## 替代方案

如果 ARM64 部署遇到无法解决的问题，考虑：

1. **使用 x86_64 服务器**：在 x86_64 + NVIDIA GPU 环境下部署
2. **使用云服务**：使用支持 x86_64 + NVIDIA GPU 的云平台
3. **等待官方支持**：关注 IndexTTS 项目更新，看是否有 ARM64 支持计划

## 联系支持

- IndexTTS 项目: https://github.com/index-tts/index-tts/issues
- NVIDIA 支持: https://www.nvidia.com/en-us/support/
- Email: indexspeech@bilibili.com

