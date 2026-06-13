@echo off
REM Configuration - Change these paths to your own
set LLAMA_PATH=U:\llama\llama-server.exe
set MODEL_PATH=U:\AI\gemma-4-12b-it-Q4_K_M.gguf

REM Start Gemma server
"%LLAMA_PATH%" --model "%MODEL_PATH%" --ctx-size 12288 --n-gpu-layers 99 --parallel 3 --cont-batching --host 127.0.0.1 --port 8070 --threads 8 --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 --temp 0.8 --repeat-penalty 1.1 --top-p 0.6 --min-p 0.02 --reasoning-budget 0

pause