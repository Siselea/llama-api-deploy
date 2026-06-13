@echo off
set LLAMA=U:\llama\llama-server.exe
set MODEL=U:\AI\gpt-oss-20b-Q4_K_M.gguf
%LLAMA% --model "%MODEL%" --ctx-size 16384 --n-gpu-layers 99 --parallel 1 --cont-batching --host 127.0.0.1 --port 8070 --threads 8 --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 --temp 0.8 --repeat-penalty 1.1 --top-p 0.6 --min-p 0.02
pause