# ADR 0001: Phased delivery — Flutter-only v1, then Go proxy + Jobs REST

## Status

Accepted

## Context

- 痛点：本机单机、本地库、粘贴入库、状态跟踪、中英摘要 + Flutter 维护向匹配判断。
- 自用时间紧：本周要先能每天刷 Upwork。
- 作品集：需要比「纯客户端调 LLM」更有说服力的后端故事；已有其他 task demo，本仓库适合展示 **AI 代理 + Jobs REST**。

## Decision

1. **v1（自用）**：仅 **Flutter** + **本地数据库**；摘要与匹配通过 **本机 OpenAI 兼容端点**（首选 Ollama + Qwen）由客户端直接调用；配置在本机，密钥不进仓库。
2. **v2（作品集）**：增加 **Go 服务**：`POST /v1/summarize`、`POST /v1/assess-match`，以及 **Jobs REST**（`GET/POST/PATCH /v1/jobs` 等）作为对外 API；Flutter 改为调 Go，本地库可保留为缓存或逐步迁为「客户端 + API 同源模型」。
3. **输入**：仅粘贴正文 + 可选 `source_url`；不做登录、抓取、浏览器扩展。

## Consequences

- v1 域模型与 UI 须与 v2 API 资源形状对齐，避免第二次大改表结构。
- v1 在桌面（macOS）上开发与自用最顺：Ollama 与本机 `localhost` 同机。
- 若 v1 目标含手机真机，需单独约定 Ollama 可达地址（见后续 ADR 或 Q 结论），不能假设 `127.0.0.1` 在设备上等于 Mac 上的 Ollama。

## Alternatives considered

- **Flutter-only 永久**：交付快，作品集后端叙事弱。
- **首版就上 Go，Flutter 只 UI**：作品集好看，但拖慢本周自用。
- **Go 只代理 LLM、Jobs 仍只存 Flutter**：实现简单，但与「Jobs REST」作品集目标不一致。
