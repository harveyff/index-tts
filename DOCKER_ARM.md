# ARM 架构部署说明

## ⚠️ 重要提示

**IndexTTS 项目对 ARM 架构的支持非常有限，可能无法在纯 ARM CPU 环境下运行。**

## 限制因素

1. **CUDA 扩展依赖**：项目包含 C++/CUDA 扩展代码（`BigVGAN/alias_free_activation/cuda/`），需要编译 CUDA 内核
2. **PyTorch CUDA 支持**：PyTorch 官方主要提供 x86_64 架构的 CUDA 预编译包，ARM64 CUDA 支持有限
3. **NVIDIA GPU 要求**：项目需要 NVIDIA GPU 和 CUDA Toolkit，ARM 架构的 CUDA 支持取决于硬件

## ARM 架构兼容性

### ✅ 可能支持的情况

- **NVIDIA Grace Hopper**：NVIDIA 的 ARM 架构服务器，支持 CUDA
- **ARM64 + 独立 NVIDIA GPU**：如果 ARM CPU 配合独立的 NVIDIA GPU（通过 PCIe）

### ❌ 不支持的情况

- **纯 ARM CPU**（无 NVIDIA GPU）
- **ARM 架构的集成 GPU**（非 NVIDIA）
- **Apple Silicon (M1/M2/M3)**：虽然支持 GPU，但 CUDA 不支持

## Spark DGX 部署建议

### 1. 确认硬件架构

首先确认你的 Spark DGX 服务器架构：

```bash
# 检查 CPU 架构
uname -m

# 检查 GPU
nvidia-smi

# 检查 CUDA 版本
nvcc --version
```

### 2. 如果是 x86_64 架构

如果 Spark DGX 是 x86_64 架构（大多数 DGX 系统都是），使用标准的 Dockerfile：

```bash
docker build -t indextts:latest -f Dockerfile .
```

### 3. 如果是 ARM64 架构 + NVIDIA GPU

如果确实是 ARM64 架构且有 NVIDIA GPU，可以尝试：

```bash
# 使用 ARM64 Dockerfile（实验性）
docker build -t indextts:arm64 -f Dockerfile.arm64 .

# 运行容器
docker run -d \
  --name indextts \
  --gpus all \
  -p 7860:7860 \
  -v $(pwd)/checkpoints:/app/checkpoints \
  -v $(pwd)/outputs:/app/outputs \
  indextts:arm64
```

**注意**：ARM64 版本可能需要：
- 手动安装 ARM64 版本的 CUDA Toolkit
- 从源码编译 PyTorch（如果官方不提供 ARM64 CUDA wheel）
- 修改 `pyproject.toml` 以使用兼容的 PyTorch 版本

### 4. 替代方案

如果 ARM 架构无法运行，考虑：

1. **使用 x86_64 服务器**：在 x86_64 架构的服务器上部署
2. **使用云服务**：使用支持 x86_64 + NVIDIA GPU 的云平台
3. **寻找替代 TTS 方案**：寻找支持 ARM 架构的 TTS 模型

## 故障排除

### 问题：CUDA 不可用

```bash
# 检查 CUDA 是否可用
python3 -c "import torch; print(torch.cuda.is_available())"

# 如果返回 False，可能需要：
# 1. 安装 ARM64 版本的 CUDA Toolkit
# 2. 从源码编译 PyTorch
```

### 问题：CUDA 扩展编译失败

如果 `BigVGAN` 的 CUDA 扩展编译失败，可能需要：
- 检查 CUDA Toolkit 版本（需要 12.8+）
- 确认 GPU 架构兼容性（compute capability）
- 检查编译工具链是否完整

### 问题：PyTorch 安装失败

ARM64 架构可能需要：
- 使用 `pip install torch --index-url https://download.pytorch.org/whl/cpu`（CPU 版本，不支持 GPU）
- 或从源码编译 PyTorch（复杂且耗时）

## 联系支持

如果遇到问题，建议：
1. 查看项目 Issues：https://github.com/index-tts/index-tts/issues
2. 联系项目维护者：indexspeech@bilibili.com
3. 确认硬件兼容性

## 总结

**强烈建议在 x86_64 + NVIDIA GPU 环境下部署 IndexTTS**。ARM 架构支持是实验性的，可能无法正常工作。

