# NUS Digital Human — Build Log

整理时间：2026-04-30
作者：troy.xu + Claude Code

---

## 一、项目是什么

一个跑在 Windows + WSL2 上的 2D 实时数字人 demo，扮演 **NUS 校园助理**：

- 用户用麦克风说话（中英文都行）
- 自动转文字（Whisper via Groq）
- AI Agent 用 NUS 知识回答（RAG + LLM）
- 数字人嘴部同步开合 + TTS 播放回答
- 全程**零按钮**（VAD 自动检测说话开始/结束）

技术路线参考李锟《AI Agent Digital Human》课程，但 LLM 换成 GitHub Models（gpt-4o-mini，免费），ASR 换成 Groq Whisper（免费），knowledge base 换成 NUS 自建 RAG。

---

## 二、当前架构

```
Windows 浏览器 (http://localhost:3000/sentio)
        │
        │  HTTP + WebSocket
        ▼
WSL2 Ubuntu-22.04 (root @ /root/work/)
├── awesome-digital-human-live2d/     ← ADH 主项目（李锟 fork）
│   ├── 后端 FastAPI :8002
│   │   ├── ASR: Whisper engine → Groq API
│   │   ├── TTS: EdgeTTS（免费）
│   │   ├── Agent: OutsideAgent → 转发到 adh_ai_agent.nus_agent
│   │   └── LLM: 不直接用，让 agent 自己调
│   └── 前端 Next.js :3000
│       ├── Live2D 数字人渲染（Hiyori 默认皮肤）
│       ├── VAD（@ricky0123/vad-react）自动语音检测
│       └── Immersive 模式：波形 + 状态文字
│
└── adh_ai_agent/                     ← NUS Agent Python 库
    ├── adh_ai_agent/nus_agent.py    ← 核心实现
    ├── data/nus_rag.npz              ← RAG 索引（24 chunks）
    └── scripts/build_rag_index.py    ← 重建索引用
```

外部依赖：
- **GitHub Models**（免费）：gpt-4o-mini 聊天 + text-embedding-3-small RAG 嵌入
- **Groq**（免费）：whisper-large-v3 语音识别
- **EdgeTTS**（微软免费）：文本转语音

**整体每问每答的成本：$0**（在三个 API 各自的免费配额内）。

---

## 三、当前能力清单

### 基础对话
- ✅ NUS 主题文本对话（来自 LLM 训练记忆 + RAG 检索）
- ✅ 中英文双语，agent 跟随用户语言
- ✅ 流式输出（边生成边显示边读）
- ✅ 短答案（max_tokens=80，1-2 句话），缓解字幕音频时差

### 语音交互
- ✅ Whisper 中英文自动识别（不用切语言开关）
- ✅ VAD 自动检测说话开始/结束（不用按按钮）
- ✅ 录音状态视觉反馈：Listening / Speaking / Transcribing 三态文字 + 颜色
- ✅ 波形条只在说话时显示（避免环境噪音误导）

### 上下文 & 知识
- ✅ 多轮对话记忆（最近 8 轮，约 16 条消息）
- ✅ 代词消解（"there"/"it"/"they" 在 LLM 上下文里被解析）
- ✅ "reset" / "重置" / "clear" 命令清空记忆
- ✅ RAG 检索（cosine similarity，top-3，24 chunks 来自 comp.nus.edu.sg）
- ✅ Guard rail：不知道的事情不编（fees、dates、dean 等）

### 工程化
- ✅ 一键启停：`start_demo.cmd` / `stop_demo.cmd`（双击即用）
- ✅ 健康检查：`scripts/health.sh`
- ✅ 烟雾测试：`scripts/smoke_test_nus.sh`、`test_rag.sh`、`test_multi_turn.sh`
- ✅ 后台进程 setsid 脱离 WSL session（不会因为关 wsl 终端被 SIGHUP 干掉）
- ✅ 默认配置自动化（首次访问就是 OutsideAgent + Whisper + Immersive，无需手动选）

---

## 四、踩过的坑（按时间顺序）

### 1. WSL 默认 Ubuntu 版本太老
**现象**：原有 WSL Ubuntu 是 20.04 / Python 3.8，OpenAI Agents SDK 要求 3.10+。
**解法**：`wsl --install -d Ubuntu-22.04 --no-launch`，再 `wsl -d Ubuntu-22.04 -u root` 跳过首次交互式 setup。
**教训**：不要直接在旧 distro 上挣扎装新 Python，干净装一个新的更稳。

### 2. NUS VPN 拦截 WSL 网络
**现象**：WSL2 内 ping 8.8.8.8 100% 丢包，`apt update` 全 timeout。
**解法**：关 Pulse Secure VPN。
**教训**：WSL2 默认走 Windows 的 NAT，企业 VPN（特别是 always-on 模式）会让 WSL 出不去。

### 3. NUS 在新加坡，清华 PyPI 镜像不可达
**现象**：`uv add` 通过清华源 connect timeout。
**解法**：去掉 `[[tool.uv.index]]` 区块，回退到默认 pypi.org。
**教训**：李锟课程默认配置面向中国大陆，海外用户要拿掉镜像源。

### 4. Git Bash 把 `$PATH` 提前展开破坏 WSL 命令
**现象**：从 Windows 端 `wsl -d Ubuntu -u root -- bash -c "...$PATH..."` 时，`$PATH` 在外层 Git Bash 就被替换成包含空格和括号的 Windows PATH，传到 WSL 后 bash 解析炸掉。
**解法**：把 shell 脚本写到文件，再 `cat file | wsl bash` 通过 stdin 喂进去。
**教训**：Windows 路径 + bash 引号嵌套是噩梦，永远走 stdin。

### 5. Cmd 双击 `.cmd` 文件路径转义不对
**现象**：路径含空格用 `\ ` 转义在 bash 里行，cmd 不认，wsl 拿到的是碎片化参数，silent fail。
**解法**：cmd 里改用 `type "%~dp0scripts\start.sh" | wsl bash` 走 stdin。
**教训**：cmd 别用 `\ ` 转义，别让 cmd 处理含空格路径，宁可走 stdin。

### 6. WSL 里 `nohup` + `&` 后台进程被 SIGHUP 杀
**现象**：`start_all.sh` 启动后台服务，wsl session 一退出，pnpm/node 进程链就死了（python 单进程的 backend 反而能活）。
**解法**：用 `setsid nohup ... < /dev/null &` 把进程放到新 session，彻底脱离 controlling terminal。
**教训**：WSL2 + 后台进程 + 多进程 tree（npm/pnpm 是典型）要 setsid。

### 7. Next.js `next start` 默认只绑 localhost
**现象**：WSL 内 curl localhost:3000 通，Windows 浏览器访问 timeout。
**解法**：`pnpm exec next start -H 0.0.0.0 -p 3000`。
**坑中坑**：`pnpm run start -- -H 0.0.0.0` 不行，pnpm 把 `--` 也透传给 next 当成参数。要用 `pnpm exec next start ...`。

### 8. ADH 默认 ASR 指向 Dify，未配置就报错
**现象**：浏览器点麦克风，后端 `Request URL is missing an 'http://' or 'https://' protocol`。
**解法**：把 default ASR 从 difyAPI.yaml 改成我们后加的 whisperAPI.yaml。
**教训**：ADH 3.0 的默认配置是给 Dify 用户的，自己用要全部检查一遍。

### 9. Web Speech API 对专有名词没救
**现象**："Where is NUS School of Computing" 被识别成 "well you send us School of computing"，"COM1" 变 "common one"，"command"。
**尝试 1**：post-processing 替换规则 → 越加越多越打地鼠。
**尝试 2（采用）**：换 Whisper（Groq 免费），自动多语言识别 + 专有名词准确。
**教训**：Web Speech API 的 vocabulary hint 在 Chrome 早就被忽略了，不要试图 regex 救场。

### 10. 字幕跑得比 TTS 快太多
**现象**：LLM 流式输出 ~50 token/s，TTS 播 ~3 字/s，字幕一秒钟读完，音频还要等 15 秒。
**解法**：缩短系统提示词到 "1-2 short sentences ~30 words"，max_tokens=400→80。
**教训**：spoken-style demo 的根治是答案变短，不是字幕做 gating（gating 工程量大）。

### 11. ADH OutsideAgent 的 `agent_type` 标 required: true
**现象**：incognito 首次访问，agent_type 没在 frontend store 里时，后端 hard fail "Missing parameter"。
**解法**：yaml 里改 `required: false`，让 backend 用 default `local_lib`。
**教训**：required + default 同时存在的设计就是个陷阱，能用默认就别 required。

### 12. `uv pip install -e ../adh_ai_agent` 找不到包
**现象**：往 adh_ai_agent 加了 `data/`、`scripts/` 目录后，setuptools auto-discovery 失败，`uv pip install -e` 报 "package discovery" 错。
**解法**：`pyproject.toml` 加 `[tool.setuptools] packages = ["adh_ai_agent"]`。
**教训**：editable install + 多顶级目录要显式声明 packages。

### 13. nus.edu.sg 主页面是 JS 渲染
**现象**：`requests + BeautifulSoup` 抓 nus.edu.sg/about 拿到的全是空 shell（< 200 字符），跳过。
**有效**：comp.nus.edu.sg 系列页面是静态 HTML，正常抓取。
**未解决**：要爬 nus.edu.sg 主站需要换 Playwright 或 Patchright。
**教训**：现代企业网站默认 JS 渲染，BeautifulSoup 路线先验证再投入。

### 14. RAG threshold 0.25 太严，代词查询命中率低
**现象**："What undergraduate programs do **they** offer?" 因为 "they" 不携带 NUS 信号，cosine 相似度卡在 0.25 以下，retrieve 返回空，LLM 没 grounding 就 fallback "I'm not sure"。
**解法**：移除 threshold，无条件返回 top-3，让 LLM 自己挑。
**教训**：小语料库（<100 chunks）不需要 threshold；threshold 是用来过滤百万级语料的噪音的，小库直接给 LLM 即可。

### 15. 两次把 API token 直接贴聊天里
**现象**：GitHub PAT 一次，Groq key 一次，都进了对话日志/system reminder。
**风险**：聊天日志保存在 `C:/Users/troy.xu/.claude/projects/.../*.jsonl`，token 暴露。
**应做**：测完立刻 revoke，生成新的本地保管。
**教训**：永远不要把 secret 贴聊天里 — Claude 看到的，磁盘日志也存了。

---

## 五、未做 / 已知限制

- ❌ **nus.edu.sg 主站没爬到**（JS 渲染）—— 招生、宿舍、食堂、奖学金等信息缺失
- ❌ **Live2D 形象不是 NUS 风格**（默认 Hiyori 二次元小姐姐）
- ❌ **历史只在内存**，backend 重启就丢
- ❌ **多窗口共享同一个 history**（单全局变量）
- ❌ **没有持久化 session**（不知道哪个用户问了啥）
- ❌ **TTS 是默认 EdgeTTS 中性女声**（没切换 NUS 角色对应的声音）
- ❌ **Whisper API 调用偶尔慢**（GitHub Models embedding API 有时 500-800ms）
- ❌ **没有错误重试机制**（API 一次失败用户就要重说）

---

## 六、文件位置速查

### Windows 端（项目根目录）
```
c:\Users\troy.xu\Downloads\AI Digital Human\nus-digital-human\
├── start_demo.cmd                      ← 双击启动
├── stop_demo.cmd                       ← 双击停止
├── BUILD_LOG.md                        ← 本文档
├── demo_questions.md                   ← 演示问题清单
└── scripts/
    ├── start_all.sh                    ← WSL 内一键启动（含 token 配置）
    ├── stop_all.sh                     ← 停止
    ├── health.sh                       ← 健康检查（backend + frontend + RAG agent）
    ├── restart_backend_only.sh         ← 只重启 backend（改完 nus_agent.py 用）
    ├── rebuild_frontend.sh             ← rebuild + 重启 frontend
    ├── reload_for_whisper.sh           ← 历史脚本（Whisper 接入时用）
    ├── build_rag_index.py              ← 重建 RAG 索引
    ├── setup_rag.sh                    ← 装 RAG 依赖 + 跑 builder
    ├── sync_rag_deps.sh                ← 把 deps 同步到 ADH backend venv
    ├── smoke_test_nus.sh               ← 5 题英文烟雾测试
    ├── test_multi_turn.sh              ← 多轮对话验证
    ├── test_rag.sh                     ← RAG 命中验证
    └── test_github_models.py           ← GitHub Models 直连测试
```

### WSL 端（实际代码 + 数据）
```
/root/work/awesome-digital-human-live2d/         ← ADH 主项目
├── configs/config.yaml                          ← 主配置（端口、默认 engine）
├── configs/agents/outsideAgent.yaml             ← OutsideAgent 参数
├── configs/engines/asr/whisperAPI.yaml          ← 我们加的 Whisper engine
├── digitalHuman/engine/asr/whisperASR.py        ← Whisper 实现
├── digitalHuman/engine/asr/__init__.py          ← 注册 WhisperApiAsr
├── web/lib/constants.ts                         ← SENTIO_CHATMODE_DEFULT = IMMSERSIVE
└── web/app/(products)/sentio/components/chatbot/input.tsx  ← VAD 状态文字 + 波形 gating

/root/work/adh_ai_agent/                         ← NUS Agent
├── pyproject.toml                               ← 含 [tool.setuptools] packages
├── adh_ai_agent/nus_agent.py                    ← 核心：history + RAG + reset
└── data/nus_rag.npz                             ← 24 chunks 索引

/var/log/nus-digital-human/                      ← 运行时日志
├── backend.log
└── frontend.log
```

---

## 七、再开机 / 再 demo 怎么办

### 启动
1. 双击 `start_demo.cmd`（自动启 WSL 服务 + 开浏览器）
2. 或者命令行：
   ```
   wsl -d Ubuntu-22.04 -u root -- bash /mnt/c/Users/troy.xu/Downloads/AI\ Digital\ Human/nus-digital-human/scripts/start_all.sh
   ```
3. 浏览器打开 http://localhost:3000/sentio（**用隐身窗口拿到自动默认值**）
4. 头一次会让你授权麦克风 → 允许

### 停止
- 双击 `stop_demo.cmd`，或 `wsl ... stop_all.sh`

### 改 NUS 系统提示词或行为
1. 编辑 WSL 内的 `/root/work/adh_ai_agent/adh_ai_agent/nus_agent.py`
   （Windows 端可走 UNC 路径：`\\wsl.localhost\Ubuntu-22.04\root\work\adh_ai_agent\adh_ai_agent\nus_agent.py`）
2. `bash scripts/restart_backend_only.sh` 让 Python 模块 reload

### 加更多 RAG 数据源
1. 编辑 `scripts/build_rag_index.py` 顶部的 `URLS` 列表
2. 在 WSL 内：
   ```
   cd /root/work/adh_ai_agent
   GITHUB_TOKEN=<你的> uv run python scripts/build_rag_index.py
   ```
3. `bash scripts/restart_backend_only.sh`

---

## 八、安全与 token 卫生

⚠️ 截至 2026-04-30 02:30，本项目跑通用了两个 token，**两个都已在聊天里暴露**：

| Token | 状态 | 在哪用到 |
|---|---|---|
| GitHub PAT (旧 `ghp_3W...`) | ⚠️ 用户已 rotate（agent_type 修复时报告过） | 不再使用 |
| GitHub PAT (新 `ghp_C0...`) | 🔴 暴露在聊天 + start_all.sh | 当前使用 |
| Groq Key (`gsk_RyQ...`) | 🔴 暴露在聊天 + start_all.sh | 当前使用 |

**Demo 跑完 / 项目结束时建议**：
1. [github.com/settings/tokens](https://github.com/settings/tokens) revoke `ghp_C0...`
2. [console.groq.com/keys](https://console.groq.com/keys) revoke `gsk_RyQ...`
3. 生成新 token，自己离线保管，**别再贴聊天**
4. 把 `start_all.sh` 加进 `.gitignore`（如果你 git 化这个项目）

通用原则：API key 只放在 env var / secret manager，不进代码、不进聊天、不进截图。

---

## 九、未来可走方向（按价值降序）

### 立刻有价值
1. **抓 nus.edu.sg 主站补 RAG**（用 Patchright/Playwright，处理 JS 渲染）—— 估时 30 分钟
2. **加 Web Search 兜底**（Brave Search API 免费 2K/月，RAG 没命中时 fallback）—— 估时 1 小时
3. **TTS 角色定制**（NUS Lion 配音 / 老练男声等）—— 估时 30 分钟，腾讯云 TTS 收费

### 中期改进
4. **Live2D 形象 NUS 化**（找设计师做带校徽配色的 2D 模型，或用 Live2D Editor 自己改）—— 估时 1-2 周
5. **session 持久化**（sqlite 存 history，按 conversation_id 隔离）—— 估时 2-3 小时
6. **错误重试**（API 失败 / 网络抖动自动重试 + 用户友好提示）—— 估时 1 小时

### 大动作
7. **从 demo 走向产品**（多用户隔离、HTTPS、SSO、监控、log shipping）—— 估时 1-2 周
8. **3D 数字人方案**（Unreal/Unity，对接 Nvidia ACE 等）—— 估时 1+ 月

---

## 十、性能数据（参考）

测试环境：Windows 11 Education + WSL2 + 没有 GPU + NUS 校园网

| 指标 | 测量值 | 备注 |
|---|---|---|
| 后端启动 | ~4 秒 | uvicorn + ADH engine init |
| 前端启动 | ~2 秒 | next start（已 build） |
| 前端 build | ~30 秒 | pnpm run build 全量 |
| Whisper（Groq）一句话 | 0.5-1.5 秒 | whisper-large-v3 |
| Embedding（GitHub Models） | 0.3-0.8 秒 | text-embedding-3-small |
| Chat first token（gpt-4o-mini） | 1-2 秒 | streaming start |
| 整体"说完到首字幕" | 3-5 秒 | 上面叠加 + 网络往返 |
| RAG 索引大小 | 24 chunks × 1536d × 4B = ~150 KB | nus_rag.npz |

---

## 十一、参考材料

- 李锟课程讲义：[../AI agent digital human.txt](../AI%20agent%20digital%20human.txt)
- ADH 上游项目：https://github.com/wan-h/awesome-digital-human-live2d
- ADH 李锟 fork：https://github.com/freecoinx/awesome-digital-human-live2d
- GitHub Models marketplace：https://github.com/marketplace/models
- Groq 控制台：https://console.groq.com
- Live2D SDK for Web：https://github.com/Live2D/CubismWebFramework
- Whisper API 协议：https://platform.openai.com/docs/api-reference/audio/createTranscription

---

记录到此。下次接手前过一遍这份文档，加上看一眼 git log（如果 git 化了的话）应该能快速 onboard。
