# 🚀 rtx3060-dual-model-api

用一张 RTX 3060 12GB 显卡，在 Windows 上部署 Gemma-4-12B 和 GPT-OSS-20B 的 OpenAI 兼容 API，支持超长上下文和双模型分时切换。

## ✨ 特性
- **双模型**：Gemma-12B (精准快速) + 20B (16384 超长上下文)
- **高性能**：Flash Attention + Q8_0 KV 缓存优化，20B 模型跑出 70+ tok/s
- **一键启动**：bat 脚本，搭配 One API 实现多用户管理
- **完全开源**：所有配置和脚本均可在本地复现

## 🧠 模型表现
| 模型 | 上下文 | 并发 | 生成速度 | 适用场景 |
|------|--------|------|----------|----------|
| Gemma-4-12B | 12288 | 3 | ~30 t/s | 日常问答、文案 |
| GPT-OSS-20B | 16384 | 1 | 70+ t/s | 长文生成、分析 |

## 🚀 性能速览

| 总请求 | 成功率 | 平均速度 | P50 延迟 | P99 延迟 |
|--------|--------|----------|----------|----------|
| 2443 | 99.92% | 90.92 tok/s | 21.98s | 44.93s |

📄 [查看完整报告](PERFORMANCE_REPORT.md)
## ⚙️ 快速开始

### 1. 下载必需软件
- [llama.cpp](https://github.com/ggerganov/llama.cpp/releases) (需下载 CUDA 版)
- [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads)
- [One API](https://github.com/songquanpeng/one-api) (可选，用于多用户管理)

### 2. 下载 GGUF 模型
- Gemma-4-12B：在 Hugging Face 搜索 `gemma-4-12b-it-Q4_K_M.gguf`
- GPT-OSS-20B：搜索 `gpt-oss-20b-Q4_K_M.gguf`

### 3. 修改启动脚本
编辑 `gemma-12b.bat` 和 `gpt-20b.bat`，把开头的路径改成你自己的：
```batch
set LLAMA_PATH=你的llama-server.exe路径
set MODEL_PATH=你的模型文件路径
