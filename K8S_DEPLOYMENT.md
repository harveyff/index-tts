# Kubernetes 容器化部署指南

## 重要说明

对于 **Kubernetes 容器化部署**：
- ✅ **CUDA Toolkit 在容器镜像内**（通过 Dockerfile 安装）
- ✅ **宿主机只需要 NVIDIA 驱动**（nvidia-smi）
- ❌ **不需要在宿主机安装 CUDA Toolkit**

## 架构说明

```
┌─────────────────────────────────────┐
│ Kubernetes Node (宿主机)            │
│  - NVIDIA Driver (nvidia-smi)      │  ← 只需要驱动
│  - NVIDIA GPU Device Plugin        │
└─────────────────────────────────────┘
           │
           │ GPU 访问
           ▼
┌─────────────────────────────────────┐
│ Container (Pod)                     │
│  - CUDA Toolkit (容器内)           │  ← 完整 CUDA 环境
│  - PyTorch + CUDA                   │
│  - IndexTTS                         │
└─────────────────────────────────────┘
```

## 前置要求

### 1. Kubernetes 集群要求

- Kubernetes 1.20+
- ARM64 (aarch64) 节点
- NVIDIA GPU 节点（GB10）

### 2. 安装 NVIDIA GPU Device Plugin

宿主机需要安装 NVIDIA GPU Device Plugin，用于 Kubernetes 识别和管理 GPU：

```bash
# 方法 1: 使用 Helm（推荐）
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update
helm install nvidia-device-plugin nvdp/nvidia-device-plugin \
  --set runtimeClassName=nvidia \
  --set nodeSelector."kubernetes\.io/arch"=arm64

# 方法 2: 使用 DaemonSet
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml
```

### 3. 验证 GPU 可用性

```bash
# 检查节点标签
kubectl get nodes --show-labels | grep arch

# 检查 GPU 资源
kubectl describe node <node-name> | grep nvidia.com/gpu

# 测试 GPU Pod
kubectl run gpu-test --rm -i --tty --image=nvidia/cuda:12.8.0-base-ubuntu22.04 \
  --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/arch":"arm64"},"containers":[{"name":"gpu-test","image":"nvidia/cuda:12.8.0-base-ubuntu22.04","command":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":1}}}]}}'
```

## 构建和推送镜像

### 1. 构建 ARM64 镜像

```bash
# 在 ARM64 机器上构建（或使用 buildx 跨平台构建）
docker build -t your-registry/indextts:arm64 -f Dockerfile.arm64 .

# 或使用 buildx（如果在 x86_64 机器上）
docker buildx create --use --name arm-builder
docker buildx build --platform linux/arm64 -t your-registry/indextts:arm64 -f Dockerfile.arm64 --load .
```

### 2. 推送镜像到仓库

```bash
docker push your-registry/indextts:arm64
```

## 部署步骤

### 1. 准备存储

创建 PVC（PersistentVolumeClaim）用于存储模型和输出：

```bash
# 创建 checkpoints PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: indextts-checkpoints
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# 创建 outputs PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: indextts-outputs
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
EOF
```

### 2. 下载模型文件

模型文件需要预先下载到 PVC：

```bash
# 方法 1: 使用 init container
# 在 k8s-deployment.yaml 中添加 init container

# 方法 2: 手动下载到 PVC
kubectl run download-models --rm -it --image=your-registry/indextts:arm64 \
  --overrides='{"spec":{"containers":[{"name":"download-models","image":"your-registry/indextts:arm64","command":["bash"],"stdin":true,"tty":true,"volumeMounts":[{"name":"checkpoints","mountPath":"/app/checkpoints"}]}],"volumes":[{"name":"checkpoints","persistentVolumeClaim":{"claimName":"indextts-checkpoints"}}]}}'

# 在容器内下载模型
# uv tool install "huggingface-hub[cli]"
# hf download IndexTeam/IndexTTS-2 --local-dir=/app/checkpoints
```

### 3. 部署应用

```bash
# 修改 k8s-deployment.yaml 中的镜像地址
# 然后部署
kubectl apply -f k8s-deployment.yaml

# 检查部署状态
kubectl get pods -l app=indextts
kubectl logs -f deployment/indextts
```

### 4. 访问服务

```bash
# 获取 Service 地址
kubectl get svc indextts-service

# 如果使用 LoadBalancer，等待 EXTERNAL-IP 分配
# 如果使用 NodePort，通过 <node-ip>:<node-port> 访问
# 如果使用 Ingress，配置相应的 Ingress 规则
```

## 配置说明

### 环境变量

容器内已设置以下 CUDA 相关环境变量（在 Dockerfile 中）：

- `CUDA_HOME=/usr/local/cuda`
- `PATH` 包含 CUDA bin 目录
- `LD_LIBRARY_PATH` 包含 CUDA lib 目录

### GPU 资源请求

```yaml
resources:
  limits:
    nvidia.com/gpu: 1  # 请求 1 个 GPU
  requests:
    nvidia.com/gpu: 1
```

### 节点选择器

```yaml
nodeSelector:
  kubernetes.io/arch: arm64  # 确保调度到 ARM64 节点
```

## 验证部署

### 1. 检查 Pod 状态

```bash
kubectl get pods -l app=indextts
kubectl describe pod <pod-name>
```

### 2. 检查 GPU 可用性

```bash
# 进入容器
kubectl exec -it deployment/indextts -- bash

# 检查 CUDA
nvcc --version
nvidia-smi

# 检查 PyTorch CUDA
python3 -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"
```

### 3. 检查服务

```bash
# 检查 Service
kubectl get svc indextts-service

# 测试连接
curl http://<service-ip>/
```

## 故障排除

### 问题 1: Pod 无法调度

**原因**: 没有可用的 ARM64 GPU 节点

**解决**:
```bash
# 检查节点
kubectl get nodes -l kubernetes.io/arch=arm64

# 检查 GPU 资源
kubectl describe node <node-name> | grep nvidia.com/gpu
```

### 问题 2: GPU 不可用

**原因**: NVIDIA Device Plugin 未安装或配置错误

**解决**:
```bash
# 检查 Device Plugin
kubectl get daemonset -n kube-system | grep nvidia

# 检查节点 GPU
kubectl describe node <node-name> | grep -A 5 "Allocated resources"
```

### 问题 3: CUDA 不可用

**原因**: 容器内 CUDA Toolkit 未正确安装

**解决**:
```bash
# 检查容器日志
kubectl logs deployment/indextts

# 进入容器检查
kubectl exec -it deployment/indextts -- nvcc --version
kubectl exec -it deployment/indextts -- python3 -c "import torch; print(torch.cuda.is_available())"
```

### 问题 4: PyTorch CUDA 不可用

**原因**: PyTorch ARM64 CUDA 版本可能不可用

**解决**: 参考 `DOCKER_ARM_GB10.md` 中的 PyTorch ARM64 CUDA 支持部分

## 性能优化

### 1. 使用 HugePages（可选）

```yaml
spec:
  containers:
  - name: indextts
    resources:
      limits:
        hugepages-2Mi: 2Gi
      requests:
        hugepages-2Mi: 2Gi
```

### 2. 设置 CPU 和内存限制

```yaml
resources:
  limits:
    cpu: "4"
    memory: "16Gi"
    nvidia.com/gpu: 1
  requests:
    cpu: "2"
    memory: "8Gi"
    nvidia.com/gpu: 1
```

### 3. 使用 Node Affinity

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/arch
          operator: In
          values:
          - arm64
```

## 总结

- ✅ **CUDA Toolkit 在容器内**：通过 Dockerfile.arm64 安装
- ✅ **宿主机只需要驱动**：nvidia-smi 和 GPU Device Plugin
- ✅ **完全容器化**：适合 Kubernetes 部署
- ⚠️ **PyTorch ARM64 CUDA**：可能需要特殊处理（见 DOCKER_ARM_GB10.md）

