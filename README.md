<a id="readme-top"></a>

<div align="center">

# pi-setup

**一键安装并配置 [Pi](https://pi.dev) 的跨平台脚本。**

跑一条命令，剩下的交给向导 —— 检测、安装、填写 base URL / API key / 模型，再个性化主题、推理档位、工具与 Pi 包，全程有提示，无需背参数。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey?style=flat-square)](#quick-start)
[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20PowerShell-4EAA25?style=flat-square)](./pi-setup.sh)
[![Node](https://img.shields.io/badge/node-%3E%3D22.19-339933?style=flat-square)](https://nodejs.org)

[快速上手](#quick-start) · [能力](#capabilities) · [脚本流程](#how-it-works) · [参数](#options) · [常见问题](#faq)

</div>

---

<a id="quick-start"></a>

## 🚀 快速上手

### 一键运行（推荐）

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/zxfccmm4/pi-setup/main/pi-setup.sh | bash
```

**Windows（PowerShell）**

```powershell
irm https://raw.githubusercontent.com/zxfccmm4/pi-setup/main/pi-setup.ps1 | iex
```

> [!NOTE]
> 脚本会自动下载配套的 `pi-config.mjs`（无需手动准备），并从 `/dev/tty` 读取输入 —— 所以 `curl | bash` 也能正常交互。下载默认走 `raw.githubusercontent.com`，失败时自动改用 jsDelivr 镜像（`cdn.jsdelivr.net`），并带连接/总时长超时。

### 三步跑通

1. **安装并配置** —— 运行上面的一键命令，按提示填写 base URL、API key、模型列表；确认后写入配置。
2. **验证 pi 就绪** —— 新开一个终端，确认命令可用：

   ```bash
   pi --version
   ```

3. **开始使用** —— 进入你的项目目录并启动：

   ```bash
   cd /path/to/project
   pi
   ```

> [!TIP]
> 想连接 Anthropic / OpenAI / Google 等内置 provider，在 Pi 里运行 `/login` 即可；本脚本负责的是**自定义端点**（OpenAI 兼容 / Anthropic 兼容）与个性化设置。

### 本地运行

```bash
git clone https://github.com/zxfccmm4/pi-setup && cd pi-setup
./pi-setup.sh
```

```powershell
git clone https://github.com/zxfccmm4/pi-setup && cd pi-setup
.\pi-setup.ps1
```

<p align="right">(<a href="#readme-top">回到顶部</a>)</p>

---

<a id="capabilities"></a>

## ✨ 能力

| 能力 | 说明 |
| --- | --- |
| 🧭 **交互式向导** | 先选语言（English / 简体中文），再逐步引导填写 base URL、API key（输入时逐字符显示 `*`，回车后回显为 `前5位...后5位`，写盘前摘要同样脱敏），自动拉取端点模型列表供编号选择，写盘前先确认。 |
| 🎛️ **模型选择** | 通过 `GET <baseUrl>/models` 拉取可用模型；选模型时可输入关键词先过滤（如 `glm` 或 `kimi`）再选编号，支持 `all` / `1,3` / `2-4`。 |
| 🛡️ **拉取不卡死** | 拉取模型列表带 20 秒超时（覆盖响应体读取，服务端挂起连接也不会永久卡住）；失败时打印具体原因（如 `HTTP 401`、`timed out after 20s`）并自动退回手动输入。 |
| 🔍 **智能检测** | 已安装 `pi` 就自动更新到最新版（走 `pi update`，已是最新则不做任何事）；未安装则询问后自动安装。**会识别并跳过其他工具的 `pi` 同名命令**（如 OmO/senpi 的别名），不会误判为已安装。 |
| 🎨 **个性化配置** | 覆盖文档中的常用设置：主题（`system`/`dark`/`light`/自动明暗）、推理档位、逐模型推理档位（`modelThinkingLevels`）、工具集（含 `+codemode` / `+tool_search`）、模型循环范围（`enabledModels`）、隐藏思考块、安静启动、缓存预热、缓存未命中提示、压缩开关、消息投递模式（`steeringMode` / `followUpMode`）、TUI 模式、外部编辑器、HTTP 代理、会话目录、项目信任、遥测/分析开关等。 |
| 🔐 **密钥存储可选** | `--auth-mode auth` 把 API key 写入 `auth.json`（自动 chmod 600），`models.json` 里不再出现明文密钥；默认仍写 `models.json`（简单直接）。 |
| 📦 **Pi 包管理** | 向导可直接添加 Pi 包（`npm:@foo/pi-tools`、`git:github.com/user/repo`、本地路径），写入 `settings.json` 的 `packages`，自动去重。 |
| 🧩 **资源路径** | `--extension` / `--skill` / `--prompt-template` / `--theme-file` 分别追加到 `settings.json` 的 `extensions` / `skills` / `prompts` / `themes`，自动去重。 |
| 🛰️ **MCP 服务器** | `--mcp-add NAME=JSON` 与 `--mcp-json FILE` 写入 `mcp.json` 的 `mcpServers`（stdio 的 `command`/`args`/`env`/`cwd` 与 HTTP 的 `url`/`headers` 均支持）；向导也可交互添加。 |
| ⌨️ **自定义快捷键** | `--keybinding ACTION=KEYS`（可重复）与 `--keybindings-json FILE` 写入 `keybindings.json`。 |
| 📝 **上下文与系统提示** | `--agents-md`、`--append-system`、`--system-md` 写入 agent 目录下的 `AGENTS.md` / `APPEND_SYSTEM.md` / `SYSTEM.md`（支持 `@文件` 读入）。 |
| 🧮 **完整模型定义** | `--models-json FILE` 读取 JSON 模型对象数组（`reasoning` / `input` / `contextWindow` / `cost` 等），把完整能力元数据写进 `models.json`，pi 会按此展示上下文长度与推理支持。 |
| 🖥️ **跨平台** | Linux / macOS 用 `pi-setup.sh`，Windows 用 `pi-setup.ps1`，配置逻辑共用 `pi-config.mjs`。 |
| 🔒 **安全写入** | 确认后才写盘，自动备份原配置（`<文件>.bak.<时间戳>`），并与已有 provider / settings **深度合并**而非覆盖。 |

<p align="right">(<a href="#readme-top">回到顶部</a>)</p>

---

<a id="how-it-works"></a>

## 🔧 脚本流程

1. **检测 pi** —— 在 `PATH` 中查找 `pi`（并兜底检查 `~/.local/bin`、`~/.pi/agent/bin`、`~/.bun/bin` 等常见目录）。校验方式是该命令 `--help` 首行为 `pi - ...`，因此其它工具的 `pi` 同名别名会被忽略并提示。
   - 已安装 → 打印版本并**更新到最新版**（`pi update`，已是最新则不做任何事；失败只告警不中断，配置步骤照常进行）。
   - 未安装 → 询问是否安装，确认后运行官方安装脚本 `curl -fsSL https://pi.dev/install.sh | sh`（Windows：`irm https://pi.dev/install.ps1 | iex`）；失败时回退到 `npm i -g --ignore-scripts @earendil-works/pi-coding-agent`。
2. **准备运行时** —— 写配置需要 Node.js 或 Bun；两者都没有时自动安装（Homebrew / NodeSource APT / Bun 脚本，见[依赖](#requirements)）。
3. **逐步配置 provider** —— 先选语言（English / 简体中文），再依次询问 base URL、API key（输入时逐字符显示 `*`，回车后该行回显为 `前5位...后5位`，不泄露完整 key）；脚本会尝试拉取 `GET <baseUrl>/models` 并把模型列表编号列出，可先输关键词过滤再选编号（`all` / `1,3` / `2-4` 均支持），拉取失败则打印原因并退回手动输入。随后是 provider 名称、API 协议、**密钥存放位置（`models.json` 或 `auth.json`）**、默认模型，最后打印摘要（模型多时只列前几个、API key 已脱敏）并请求确认。
4. **个性化设置（可选）** —— 确认 provider 后，向导询问是否继续配置主题、推理档位、工具集、思考块显示、启动信息、缓存预热、Pi 包、MCP 服务器与全局 AGENTS.md，全部可留空跳过。
5. **写入配置** —— 确认后才写盘；输入 `n` 取消且不产生任何文件。

<p align="right">(<a href="#readme-top">回到顶部</a>)</p>

---

<a id="files"></a>

## 📦 写入的配置文件

默认目录 `~/.pi/agent`（可用 `PI_CODING_AGENT_DIR` 覆盖）。

| 文件 | 作用 |
| --- | --- |
| `~/.pi/agent/models.json` | 新增/更新 `providers.<名称>`（`baseUrl` / `api` / `apiKey` / `models`）。 |
| `~/.pi/agent/auth.json` | `--auth-mode auth` 时存放 `{ "<名称>": { "type": "api_key", "key": "..." } }`（权限 600）。 |
| `~/.pi/agent/settings.json` | 设置 `defaultProvider` / `defaultModel`，以及个性化项（`theme` / `defaultThinkingLevel` / `defaultTools` / `packages` 等）。 |
| `~/.pi/agent/mcp.json` | `mcpServers` 下的 MCP 服务器（stdio / HTTP）。 |
| `~/.pi/agent/keybindings.json` | 动作到按键的映射。 |
| `~/.pi/agent/AGENTS.md` | 对所有项目生效的持久指令（`APPEND_SYSTEM.md` / `SYSTEM.md` 同理）。 |

`models.json` —— 新增/更新 `providers.<名称>`：

```json
{
  "providers": {
    "example-com": {
      "baseUrl": "https://api.example.com/v1",
      "api": "openai-completions",
      "apiKey": "sk-xxx",
      "models": [{ "id": "glm-5.3", "name": "GLM-5.3" }]
    }
  }
}
```

`settings.json` —— 默认模型与个性化：

```json
{
  "defaultProvider": "example-com",
  "defaultModel": "glm-5.3",
  "theme": "dark",
  "defaultThinkingLevel": "high",
  "defaultTools": ["+codemode"]
}
```

> [!IMPORTANT]
> 写入前会自动生成时间戳备份（`<文件>.bak.<时间戳>`），并与已有配置**深度合并**而非覆盖。`defaultModel` 存的是**裸模型 id**（`defaultProvider` 单独记录），脚本会自动去掉 `provider/` 前缀。

> [!NOTE]
> `api` 取值：`openai-completions`（大多数 OpenAI 兼容端点）、`openai-responses`（Responses API）、`anthropic-messages`（Anthropic 兼容端点）。

<p align="right">(<a href="#readme-top">回到顶部</a>)</p>

---

<a id="options"></a>

## ⚙️ 参数

### 常用参数速查

| 目标 | 命令 |
| --- | --- |
| 非交互配置 provider | `./pi-setup.sh --base-url URL --api-key KEY --models a,b` |
| 指定协议与默认模型 | `./pi-setup.sh --base-url URL --api-key KEY --models a --api-type openai-responses --default-model a` |
| 只做个性化 | `./pi-setup.sh --skip-install --theme dark --thinking high` |
| 加装 Pi 包 | `./pi-setup.sh --skip-install --package npm:@foo/pi-tools` |
| 密钥存入 auth.json | `./pi-setup.sh --skip-install --auth-mode auth --base-url URL --api-key KEY --models a` |
| 加 MCP 服务器 | `./pi-setup.sh --skip-install --mcp-add 'fs={"command":"npx","args":["-y","@modelcontextprotocol/server-filesystem","."]}'` |
| 加全局指令 | `./pi-setup.sh --skip-install --agents-md 'Always answer concisely.'` |
| 完整模型定义 | `./pi-setup.sh --skip-install --base-url URL --api-key KEY --models-json ./my-models.json` |
| 预演不写盘 | `./pi-setup.sh --dry-run --base-url URL --api-key KEY --models a` |
| 不碰个性化 | `./pi-setup.sh --no-customize --base-url URL --api-key KEY --models a` |

### 完整参数表

| 参数 | 说明 |
| --- | --- |
| `-i`, `--interactive` | 强制进入逐步向导 |
| `--base-url URL` | 端点 base URL（环境变量 `PISETUP_BASE_URL`） |
| `--api-key KEY` | API key（环境变量 `PISETUP_API_KEY`） |
| `--models a,b,c` | 逗号分隔的模型 id（环境变量 `PISETUP_MODELS`） |
| `--models-file FILE` | 读取 `id<TAB>name` 行作为模型列表 |
| `--models-json FILE` | 读取 JSON 模型对象数组（含 `reasoning` / `input` / `contextWindow` / `cost` 等完整元数据） |
| `--auth-mode models\|auth` | `models`（默认，密钥写 `models.json`）或 `auth`（写 `auth.json`，权限 600） |
| `--lang en\|zh` | 向导与输出语言（环境变量 `PISETUP_LANG`，默认 `en`） |
| `--provider NAME` | provider 名称（默认由域名推导） |
| `--api-type TYPE` | `openai-completions` \| `openai-responses` \| `anthropic-messages` |
| `--default-model ID` | 默认模型（默认 `provider/<第一个模型>`） |
| `--no-default` | 不改动 `settings.json` 的默认模型 |
| `--theme NAME` | `system` \| `dark` \| `light` \| `light/dark` \| 自定义主题名 |
| `--thinking LEVEL` | `off` \| `minimal` \| `low` \| `medium` \| `high` \| `xhigh` \| `max` |
| `--tools LIST` | `defaultTools`，如 `+codemode` 或 `read,bash,+codemode` |
| `--hide-thinking on\|off` | 是否隐藏思考块 |
| `--quiet-startup on\|off\|header` | 启动信息精简程度 |
| `--cache-warming off\|streaming\|idle` | 提示缓存预热模式 |
| `--cache-miss-notices on\|off` | 缓存命中/成本提示（`showCacheMissNotices`） |
| `--collapse-changelog on\|off` | 更新后只显示精简 changelog |
| `--model-thinking PROVIDER/MODEL=LEVEL` | 逐模型推理档位（`modelThinkingLevels`，可重复） |
| `--enabled-models LIST` | `Ctrl+P` 循环的模型范围（`enabledModels`） |
| `--compaction on\|off` | 自动压缩开关（`compaction.enabled`） |
| `--steering all\|one-at-a-time` | 引导消息投递方式（`steeringMode`） |
| `--follow-up all\|one-at-a-time` | 跟进消息投递方式（`followUpMode`） |
| `--tui-mode regular\|fullscreen` | 交互界面模式 |
| `--editor CMD` | `Ctrl+G` 外部编辑器命令 |
| `--http-proxy URL` | Pi 网络请求代理（仅 agent 目录设置生效） |
| `--session-dir DIR` | 会话存储目录 |
| `--project-trust ask\|always\|never` | 项目信任默认行为（仅 agent 目录设置生效） |
| `--telemetry on\|off` | 安装/更新匿名遥测 |
| `--analytics on\|off` | 分析数据共享（默认关） |
| `--skill-commands on\|off` | 是否注册 `/skill:name` 命令 |
| `--extension PATH` | 追加 `settings.extensions`（可重复） |
| `--skill PATH` | 追加 `settings.skills`（可重复） |
| `--prompt-template PATH` | 追加 `settings.prompts`（可重复） |
| `--theme-file PATH` | 追加 `settings.themes`（可重复） |
| `--mcp-add NAME=JSON` | 添加/合并 MCP 服务器（可重复） |
| `--mcp-json FILE` | 从文件合并 `mcpServers` |
| `--keybinding ACTION=KEYS` | 设置快捷键，多个键用逗号分隔（可重复） |
| `--keybindings-json FILE` | 从文件合并快捷键映射 |
| `--agents-md TEXT\|@FILE` | 写 `<agent-dir>/AGENTS.md` |
| `--append-system TEXT\|@FILE` | 写 `<agent-dir>/APPEND_SYSTEM.md` |
| `--system-md TEXT\|@FILE` | 写 `<agent-dir>/SYSTEM.md`（替换默认系统提示） |
| `--package SOURCE` | 追加 Pi 包（可重复） |
| `--set-json JSON` | 深度合并任意合法 settings（可重复） |
| `--no-customize` | 除 provider 默认值外不改动 `settings.json` |
| `--dry-run` | 只打印将要写入的内容 |
| `--skip-install` | 跳过安装/更新检查，只写配置 |

> [!NOTE]
> `pi-setup.sh` / `pi-setup.ps1` 通过 `PISETUP_RAW_BASE` 环境变量覆盖下载 `pi-config.mjs` 的地址（默认 `raw.githubusercontent.com/zxfccmm4/pi-setup/main`）。如果你 fork 了本仓库并修改了 `pi-config.mjs`，用 `PISETUP_RAW_BASE=https://raw.githubusercontent.com/<你的用户名>/pi-setup/main bash` 即可让一键命令拉取你自己的版本。

`pi-config.mjs` 可单独使用，另支持 `--fetch-models`、`--print-provider`、`--print-models` 与 `--lang`。

<p align="right">(<a href="#readme-top">回到顶部</a>)</p>

---

<a id="requirements"></a>

## 📋 依赖

| 组件 | 要求 | 说明 |
| --- | --- | --- |
| Pi | Node.js **22.19+** | 官方安装器会自动处理 Node 缺失；npm 安装需自行满足。 |
| 配置写入 | Node.js **18+** 或 Bun | 仅在系统没有 Node/Bun 时自动安装。 |

<p align="right">(<a href="#readme-top">回到顶部</a>)</p>

---

<a id="faq"></a>

## ❓ 常见问题

<details>
<summary><b>运行后 `pi` 找不到怎么办？</b></summary>

官方安装器会把 pi 放到托管目录并把可执行文件软链到 PATH 中的某个目录（如 `~/.local/bin` 或 `~/.pi/agent/bin`）。若当前 shell 尚未刷新 PATH，请新开一个终端，或按安装器提示把对应目录加进 `~/.zshrc` / `~/.bashrc`。

</details>

<details>
<summary><b>`pi` 命令被其它工具占用了？</b></summary>

脚本通过 `pi --help` 首行是否为 `pi - ...` 来识别真正的 pi.dev Pi。如果 PATH 上的 `pi` 是其它工具（例如 OmO/senpi）的同名别名，脚本会打印提示并忽略它，继续按「未安装」处理，不会误判。

</details>

<details>
<summary><b>如何连接 Anthropic / OpenAI / Google 等内置 provider？</b></summary>

本脚本面向自定义端点。内置 provider 请直接在 Pi 里运行 `/login` 完成 OAuth 或 API key 登录；也可以用环境变量（如 `ANTHROPIC_API_KEY`）供 Pi 读取。

</details>

<details>
<summary><b>想配置本地模型（Ollama / LM Studio / vLLM）？</b></summary>

用向导把 base URL 填成对应地址即可，例如 Ollama：`http://localhost:11434/v1`，协议选 `openai-completions`，API key 随便填一个非空值（Ollama 会忽略）。

</details>

<details>
<summary><b>配置写坏了怎么回滚？</b></summary>

每次写入前都会生成 `<文件>.bak.<时间戳>` 备份，直接覆盖回去即可：

```bash
ls ~/.pi/agent/*.bak.*
cp ~/.pi/agent/settings.json.bak.<时间戳> ~/.pi/agent/settings.json
```

</details>

<details>
<summary><b>如何卸载 Pi？</b></summary>

```bash
# 官方安装器安装的：
curl -fsSL https://pi.dev/install.sh | sh    # 选择 Uninstall Pi

# npm 安装的：
npm uninstall -g @earendil-works/pi-coding-agent
```

两种方式都不会删除 `~/.pi/agent/` 下的配置、凭据、会话与已安装的 Pi 包。

</details>

<p align="right">(<a href="#readme-top">回到顶部</a>)</p>

---

## 📄 许可证

[MIT](./LICENSE)
