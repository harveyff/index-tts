#!/bin/bash
# ARM64 CUDA Toolkit 安装脚本
# 适用于：aarch64 + NVIDIA GB10 (Grace Blackwell)

set -e

echo "=========================================="
echo "ARM64 CUDA Toolkit 安装脚本"
echo "适用于: aarch64 + NVIDIA GB10"
echo "=========================================="

# 检查架构
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "警告: 当前架构是 $ARCH，不是 aarch64"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查 NVIDIA 驱动
if ! command -v nvidia-smi &> /dev/null; then
    echo "错误: 未找到 nvidia-smi，请先安装 NVIDIA 驱动"
    exit 1
fi

echo "✓ 检测到 NVIDIA GPU"
nvidia-smi --query-gpu=name --format=csv,noheader

# 检查是否已安装 CUDA Toolkit
if command -v nvcc &> /dev/null; then
    echo "✓ 检测到已安装的 CUDA Toolkit:"
    nvcc --version
    read -p "是否重新安装? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "跳过安装"
        exit 0
    fi
fi

# 检测 Ubuntu 版本
if [ -f /etc/os-release ]; then
    . /etc/os-release
    UBUNTU_VERSION=$VERSION_ID
    echo "检测到 Ubuntu 版本: $UBUNTU_VERSION"
else
    echo "错误: 无法检测 Ubuntu 版本"
    exit 1
fi

# 添加 NVIDIA CUDA 仓库（ARM64/SBSA）
echo ""
echo "步骤 1: 添加 NVIDIA CUDA 仓库..."
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_VERSION}/sbsa/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# 安装 CUDA Toolkit
echo ""
echo "步骤 2: 安装 CUDA Toolkit..."
echo "可用的 CUDA Toolkit 版本:"
apt-cache search cuda-toolkit | grep "^cuda-toolkit"

# 默认安装 12.8（与项目要求匹配）
CUDA_VERSION="12-8"
echo ""
read -p "输入要安装的 CUDA 版本 (例如: 12-8, 12-6, 11-8) [默认: $CUDA_VERSION]: " input
CUDA_VERSION=${input:-$CUDA_VERSION}

echo "安装 cuda-toolkit-$CUDA_VERSION..."
sudo apt-get install -y cuda-toolkit-$CUDA_VERSION

# 设置环境变量
echo ""
echo "步骤 3: 配置环境变量..."
CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# 添加到 ~/.bashrc（如果存在）
if [ -f ~/.bashrc ]; then
    if ! grep -q "CUDA_HOME" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# CUDA" >> ~/.bashrc
        echo "export CUDA_HOME=$CUDA_HOME" >> ~/.bashrc
        echo "export PATH=\$CUDA_HOME/bin:\$PATH" >> ~/.bashrc
        echo "export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc
        echo "✓ 已添加到 ~/.bashrc"
    fi
fi

# 验证安装
echo ""
echo "步骤 4: 验证安装..."
if command -v nvcc &> /dev/null; then
    echo "✓ CUDA Toolkit 安装成功:"
    nvcc --version
else
    echo "✗ 警告: nvcc 命令未找到，可能需要重新加载 shell 或手动设置 PATH"
    echo "请运行: source ~/.bashrc 或 export PATH=$CUDA_HOME/bin:\$PATH"
fi

# 清理
rm -f cuda-keyring_1.1-1_all.deb

echo ""
echo "=========================================="
echo "安装完成！"
echo "=========================================="
echo ""
echo "下一步:"
echo "1. 重新加载 shell: source ~/.bashrc"
echo "2. 验证 CUDA: nvcc --version"
echo "3. 构建 Docker 镜像: docker build -t indextts:arm64 -f Dockerfile.arm64 ."
echo ""

