<#
.SYNOPSIS
  Install or update Pi (https://pi.dev), then configure a provider and
  personalize settings, step by step.

.DESCRIPTION
  Windows entry point. Mirrors pi-setup.sh and shares pi-config.mjs for the
  actual config write. Run with no arguments for an interactive wizard, or pass
  parameters for scripted use. On Linux/macOS use pi-setup.sh instead.

.EXAMPLE
  .\pi-setup.ps1

.EXAMPLE
  .\pi-setup.ps1 -BaseUrl https://api.example.com/v1 -ApiKey sk-xxx -Models gpt-4o,gpt-4o-mini

.EXAMPLE
  .\pi-setup.ps1 -Theme dark -Tools '+codemode' -Package 'npm:@foo/pi-tools'
#>
[CmdletBinding()]
param(
  [string]$BaseUrl  = $env:PISETUP_BASE_URL,
  [string]$ApiKey   = $env:PISETUP_API_KEY,
  [string]$Models   = $env:PISETUP_MODELS,
  [string]$ModelsFile,
  [string]$Lang     = $(if ($env:PISETUP_LANG) { $env:PISETUP_LANG } else { 'en' }),
  [string]$Provider = $env:PISETUP_PROVIDER,
  [ValidateSet('openai-completions','openai-responses','anthropic-messages')]
  [string]$ApiType  = $(if ($env:PISETUP_API_TYPE) { $env:PISETUP_API_TYPE } else { 'openai-completions' }),
  [string]$DefaultModel,
  [ValidateSet('models','auth')]
  [string]$AuthMode = $(if ($env:PISETUP_AUTH_MODE) { $env:PISETUP_AUTH_MODE } else { 'models' }),
  [string]$Theme,
  [string]$Thinking,
  [string]$Tools,
  [ValidateSet('on','off')]
  [string]$HideThinking,
  [ValidateSet('on','off','header')]
  [string]$QuietStartup,
  [ValidateSet('off','streaming','idle')]
  [string]$CacheWarming,
  [ValidateSet('on','off')]
  [string]$CacheMissNotices,
  [ValidateSet('on','off')]
  [string]$CollapseChangelog,
  [ValidateSet('on','off')]
  [string]$SkillCommands,
  [string]$EnabledModels,
  [ValidateSet('on','off')]
  [string]$Compaction,
  [ValidateSet('all','one-at-a-time')]
  [string]$Steering,
  [ValidateSet('all','one-at-a-time')]
  [string]$FollowUp,
  [ValidateSet('regular','fullscreen')]
  [string]$TuiMode,
  [string]$Editor,
  [string]$HttpProxy,
  [string]$SessionDir,
  [ValidateSet('ask','always','never')]
  [string]$ProjectTrust,
  [ValidateSet('on','off')]
  [string]$Telemetry,
  [ValidateSet('on','off')]
  [string]$Analytics,
  [string]$ModelsJson,
  [string[]]$ModelThinking = @(),
  [string[]]$Package = @(),
  [string[]]$SetJson = @(),
  [string[]]$Extension = @(),
  [string[]]$Skill = @(),
  [string[]]$PromptTemplate = @(),
  [string[]]$ThemeFile = @(),
  [string[]]$McpAdd = @(),
  [string]$McpJson,
  [string[]]$Keybinding = @(),
  [string]$KeybindingsJson,
  [string]$AgentsMd,
  [string]$AppendSystem,
  [string]$SystemMd,
  [switch]$NoCustomize,
  [switch]$Interactive,
  [switch]$NoDefault,
  [switch]$DryRun,
  [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$RawBase = if ($env:PISETUP_RAW_BASE) { $env:PISETUP_RAW_BASE } else { 'https://raw.githubusercontent.com/zxfccmm4/pi-setup/main' }
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$script:LangCode = 'en'
if ($Lang -match '^(zh|zh-cn|zh-hans|cn)$') { $script:LangCode = 'zh' }
elseif ($Lang -notmatch '^(en|en-us)$') { Write-Host "xx unknown -Lang '$Lang' (use en or zh)" -ForegroundColor Red; exit 1 }

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "!! $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "xx $m" -ForegroundColor Red; exit 1 }

function Mask($s) {
  if (-not $s) { return '' }
  if ($s.Length -le 10) { return '********' }
  return $s.Substring(0,5) + '...' + $s.Substring($s.Length-5)
}

function Ask($msg, $default) {
  if ($default) { Write-Host "$msg [$default]: " -NoNewline -ForegroundColor Gray }
  else { Write-Host "${msg}: " -NoNewline -ForegroundColor Gray }
  $v = [Console]::ReadLine()
  if ([string]::IsNullOrEmpty($v)) { return $default }
  return $v
}

function Ask-Secret($msg) {
  Write-Host "${msg}: " -NoNewline -ForegroundColor Gray
  $val = ''
  while ($true) {
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq [ConsoleKey]::Enter) { break }
    if ($key.Key -eq [ConsoleKey]::Backspace) {
      if ($val.Length -gt 0) { $val = $val.Substring(0, $val.Length - 1); Write-Host "`b `b" -NoNewline }
      continue
    }
    if ($key.KeyChar -and [int][char]$key.KeyChar -ge 32) {
      $val += $key.KeyChar
      Write-Host '*' -NoNewline
    }
  }
  $masked = Mask $val
  Write-Host "$([char]27)[A`r$([char]27)[K${msg}: $masked"
  return $val
}

function Ask-Yes($msg, $default) {
  if (-not $default) { $default = 'n' }
  Write-Host "$msg [$default]: " -NoNewline -ForegroundColor Gray
  $v = [Console]::ReadLine()
  if ([string]::IsNullOrEmpty($v)) { $v = $default }
  return ($v -match '^(y|yes)$')
}

function Lc($en, $zh) { if ($script:LangCode -eq 'zh') { return $zh } return $en }

function Select-Language {
  $default = if ($script:LangCode -eq 'zh') { '2' } else { '1' }
  Write-Host '0) Language / 语言:  1) English  2) 简体中文'
  $v = Ask (Lc '   choose [1-2]' '   请选择 [1-2]') $default
  if ($v -eq '2') { $script:LangCode = 'zh' } else { $script:LangCode = 'en' }
  Info (Lc 'language: English' '语言：简体中文')
}

function Ensure-Runtime {
  if (Get-Command node -ErrorAction SilentlyContinue) { return }
  if (Get-Command bun -ErrorAction SilentlyContinue) { return }

  Info (Lc 'node.js / bun not found; installing a JavaScript runtime automatically' '未找到 node.js / bun；将自动安装 JavaScript 运行时')

  if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    }
    elseif (Get-Command choco -ErrorAction SilentlyContinue) {
      choco install nodejs-lts -y
    }
    elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
      scoop install nodejs-lts
    }
    else {
      Warn 'No supported package manager found for Node.js on Windows; trying Bun as fallback'
    }
  }
  elseif ($IsMacOS) {
    if (Get-Command brew -ErrorAction SilentlyContinue) { brew install node }
  }
  elseif (Get-Command apt-get -ErrorAction SilentlyContinue) {
    $sudo = $null
    if ((id -u) -ne 0 -and (Get-Command sudo -ErrorAction SilentlyContinue)) { $sudo = 'sudo' }
    if ($sudo) { & $sudo apt-get update } else { apt-get update }
    if ($sudo) { & $sudo apt-get install -y ca-certificates curl gnupg } else { apt-get install -y ca-certificates curl gnupg }
    $keyring = '/etc/apt/keyrings/nodesource.gpg'
    $list = '/etc/apt/sources.list.d/nodesource.list'
    if (-not (Test-Path $keyring) -or -not (Test-Path $list)) {
      New-Item -ItemType Directory -Force -Path '/etc/apt/keyrings' | Out-Null
      $repoKey = (Invoke-WebRequest -Uri 'https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key' -UseBasicParsing).Content
      [System.IO.File]::WriteAllBytes($keyring, [System.Text.Encoding]::UTF8.GetBytes($repoKey))
      @('deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main') | Set-Content -Path $list
    }
    if ($sudo) { & $sudo apt-get update; & $sudo apt-get install -y nodejs }
    else { apt-get update; apt-get install -y nodejs }
  }

  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    if (Get-Command curl -ErrorAction SilentlyContinue) {
      Info (Lc 'falling back to a Bun install' '回退为安装 Bun')
      & curl -fsSL https://bun.sh/install.ps1 | powershell -c -
      if (Get-Command bun -ErrorAction SilentlyContinue) { return }
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      winget install --id Oven-sh.Bun --accept-source-agreements --accept-package-agreements
    }
  }

  if (-not (Get-Command node -ErrorAction SilentlyContinue) -and -not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Die 'could not install node.js or bun automatically on this platform'
  }
}

function Test-RealPi($bin) {
  try { $head = (& $bin --help 2>$null | Select-Object -First 1) } catch { return $false }
  return [bool]($head -match '^pi\s+-') 
}

function Find-Pi {
  $cmd = Get-Command pi -ErrorAction SilentlyContinue
  if ($cmd) {
    if (Test-RealPi $cmd.Source) { return $cmd.Source }
    Warn (Lc "the 'pi' on PATH is not pi.dev's Pi ($($cmd.Source)); ignoring it" "PATH 上的 'pi' 不是 pi.dev 的 Pi（$($cmd.Source)）；已忽略")
  }
  foreach ($d in @("$env:LOCALAPPDATA\pi\bin", "$env:USERPROFILE\.pi\agent\bin", "$env:USERPROFILE\.bun\bin", "$env:APPDATA\npm")) {
    foreach ($name in @('pi.exe','pi.cmd','pi.ps1','pi')) {
      $p = Join-Path $d $name
      if ((Test-Path $p) -and (Test-RealPi $p)) { return $p }
    }
  }
  return $null
}

function Install-Pi {
  Info (Lc 'installing Pi (https://pi.dev)' '正在安装 Pi（https://pi.dev）')
  try {
    Invoke-RestMethod -Uri 'https://pi.dev/install.ps1' | Invoke-Expression | Out-Null
    return $true
  } catch {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
      npm install -g --ignore-scripts '@earendil-works/pi-coding-agent' | Out-Null
      return ($LASTEXITCODE -eq 0)
    }
    Warn "official installer failed and no npm fallback: $($_.Exception.Message)"
    return $false
  }
}

function Update-Pi($bin) {
  if ($DryRun) { Info (Lc 'would check for a newer Pi release (pi update)' '将检查 Pi 新版本（pi update）'); return }
  Info (Lc 'checking for a newer Pi release' '正在检查 Pi 新版本')
  & $bin update
  if ($LASTEXITCODE -ne 0) { Warn (Lc "'pi update' failed; continuing with the installed version" "'pi update' 失败；继续使用已安装版本") }
}

function Get-ConfigScript {
  if ($ScriptDir) {
    $local = Join-Path $ScriptDir 'pi-config.mjs'
    if (Test-Path $local) { return $local }
  }
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pi-config-{0}.mjs" -f ([Guid]::NewGuid().ToString('N')))
  Info 'downloading pi-config.mjs'
  $urls = @("$RawBase/pi-config.mjs", 'https://cdn.jsdelivr.net/gh/zxfccmm4/pi-setup@main/pi-config.mjs')
  foreach ($url in $urls) {
    try {
      Invoke-RestMethod -Uri $url -OutFile $tmp -TimeoutSec 120
      if ((Test-Path $tmp) -and (Get-Item $tmp).Length -gt 0) { return $tmp }
    } catch {
      Warn "download failed from $url : $($_.Exception.Message)"
    }
  }
  Die 'failed to download pi-config.mjs (tried raw.githubusercontent.com and cdn.jsdelivr.net)'
}

function Get-RemoteModels {
  if (-not $BaseUrl) { return $null }
  $cfg = Get-ConfigScript
  $fetchArgs = @('--fetch-models', '--base-url', $BaseUrl, '--lang', $script:LangCode)
  if ($ApiKey) { $fetchArgs += @('--api-key', $ApiKey) }
  $errFile = [System.IO.Path]::GetTempFileName()
  $raw = $null
  try {
    if (Get-Command node -ErrorAction SilentlyContinue) { $raw = & node $cfg @fetchArgs 2>$errFile }
    elseif (Get-Command bun -ErrorAction SilentlyContinue) { $raw = & bun $cfg @fetchArgs 2>$errFile }
    else { Die 'need node or bun to fetch models' }
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
      $why = (Get-Content -Path $errFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() } | Select-Object -Last 1)
      if ($why) { Warn $why }
      return $null
    }
  } finally {
    Remove-Item -Path $errFile -Force -ErrorAction SilentlyContinue
  }
  $out = @()
  foreach ($line in @($raw)) {
    if (-not $line) { continue }
    $parts = $line -split "`t", 2
    $id = $parts[0].Trim()
    if (-not $id) { continue }
    $name = if ($parts.Count -gt 1 -and $parts[1].Trim()) { $parts[1].Trim() } else { $id }
    $out += [pscustomobject]@{ Id = $id; Name = $name }
  }
  if ($out.Count -eq 0) { return $null }
  return $out
}

function Get-ProviderName {
  if ($Provider) { return $Provider }
  if (-not $BaseUrl) { return $null }
  $cfg = Get-ConfigScript
  $out = & node $cfg --print-provider --base-url $BaseUrl --lang $script:LangCode 2>$null
  if ($LASTEXITCODE -eq 0 -and $out) { $script:Provider = ($out | Select-Object -First 1).Trim() }
  return $script:Provider
}

function Build-View($list, $filter) {
  if (-not $filter) { return @($list) }
  return @($list | Where-Object { "$($_.Id) $($_.Name)" -like "*$filter*" })
}

function Show-View($view, $max) {
  for ($i = 0; $i -lt [Math]::Min($view.Count, $max); $i++) {
    Write-Host ("   {0}) {1}`t{2}" -f ($i + 1), $view[$i].Id, $view[$i].Name)
  }
  if ($view.Count -gt $max) {
    Write-Host (Lc "   ... $($view.Count - $max) more - type text to filter, or r for the full list" "   还有 $($view.Count - $max) 个 - 输入文字过滤，或输入 r 显示全部")
  }
  Write-Host (Lc "   ($($view.Count) shown)" "   （共 $($view.Count) 个）")
}

function Select-Models($list) {
  $filter = ''
  while ($true) {
    $view = Build-View $list $filter
    if ($view.Count -eq 0) { Warn (Lc 'nothing matched that filter' '没有匹配的模型'); $filter = ''; continue }
    Write-Host ''
    Write-Host (Lc "models from ${BaseUrl}:" "来自 ${BaseUrl} 的模型：")
    Show-View $view 60
    $input = Ask (Lc 'select: all / 1,3 / 2-4 / text filter (blank = all)' '请选择：all / 1,3 / 2-4 / 过滤词（留空=全部）') ''
    if (-not $input -or $input -match '^(all|ALL)$') {
      return (($view | ForEach-Object { $_.Id }) -join ',')
    }
    $ids = @()
    $valid = $true
    foreach ($token in ($input -replace ',', ' ').Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)) {
      if ($token -match '^(\d+)-(\d+)$') {
        $a = [int]$Matches[1]; $b = [int]$Matches[2]
        if ($a -lt 1 -or $b -gt $view.Count -or $a -gt $b) { $valid = $false; break }
        for ($i = $a; $i -le $b; $i++) { $ids += $view[$i - 1].Id }
      } elseif ($token -match '^(\d+)$') {
        $i = [int]$token
        if ($i -lt 1 -or $i -gt $view.Count) { $valid = $false; break }
        $ids += $view[$i - 1].Id
      } else {
        $valid = $false
        break
      }
    }
    if (-not $valid -or $ids.Count -eq 0) {
      if ($valid) { $filter = $input } else { Warn (Lc "invalid selection '$input'" "无效的选择 '$input'") }
      continue
    }
    return (($ids | Select-Object -Unique) -join ',')
  }
}

function Select-OneModel($list) {
  $filter = ''
  $max = 15
  while ($true) {
    $view = Build-View $list $filter
    if ($view.Count -eq 0) { Warn (Lc 'nothing matched that filter' '没有匹配的模型'); $filter = ''; continue }
    Write-Host ''
    Write-Host (Lc 'pick a model:' '选择模型：')
    Show-View $view $max
    $input = Ask (Lc 'number / text to filter / r = all / blank = skip' '编号 / 文字过滤 / r 全部 / 留空跳过') ''
    if (-not $input) { return $null }
    if ($input -match '^(r|R|all|ALL)$') { $max = 200; continue }
    if ($input -notmatch '^(\d+)$') { $filter = $input; continue }
    $i = [int]$input
    if ($i -lt 1 -or $i -gt $view.Count) { Warn (Lc "invalid number '$input'" "无效编号 '$input'"); continue }
    $prov = Get-ProviderName
    if (-not $prov) { return $view[$i - 1].Id }
    return "$prov/$($view[$i - 1].Id)"
  }
}

function Invoke-CustomizeWizard {
  Write-Host ''
  Info (Lc 'personalize Pi (blank = keep current / skip)' '个性化 Pi 配置（留空 = 保持现状 / 跳过）')
  Write-Host ''

  Write-Host (Lc 'a) Theme: 1) system  2) dark  3) light  4) light/dark (auto)  (blank = skip)' 'a) 主题：1) system  2) dark  3) light  4) light/dark（自动） （留空=跳过）')
  $v = Ask (Lc '   choose [1-4]' '   请选择 [1-4]') ''
  switch ($v) {
    '1' { $script:Theme = 'system' }
    '2' { $script:Theme = 'dark' }
    '3' { $script:Theme = 'light' }
    '4' { $script:Theme = 'light/dark' }
    ''  { }
    default { $script:Theme = $v }
  }

  Write-Host (Lc 'b) Thinking level: 1) off  2) minimal  3) low  4) medium  5) high  6) xhigh  7) max  (blank = skip)' 'b) 推理档位：1) off  2) minimal  3) low  4) medium  5) high  6) xhigh  7) max （留空=跳过）')
  $v = Ask (Lc '   choose [1-7]' '   请选择 [1-7]') ''
  switch ($v) {
    '1' { $script:Thinking = 'off' }
    '2' { $script:Thinking = 'minimal' }
    '3' { $script:Thinking = 'low' }
    '4' { $script:Thinking = 'medium' }
    '5' { $script:Thinking = 'high' }
    '6' { $script:Thinking = 'xhigh' }
    '7' { $script:Thinking = 'max' }
    ''  { }
    default { $script:Thinking = $v }
  }

  Write-Host (Lc 'c) Tools: 1) keep defaults  2) defaults + codemode  3) defaults + codemode + tool_search  4) type a list' 'c) 工具：1) 保持默认  2) 默认 + codemode  3) 默认 + codemode + tool_search  4) 手动输入列表')
  $v = Ask (Lc '   choose [1-4]' '   请选择 [1-4]') ''
  switch ($v) {
    '1' { $script:Tools = '__keep__' }
    '2' { $script:Tools = '+codemode' }
    '3' { $script:Tools = '+codemode,+tool_search' }
    '4' { $script:Tools = (Ask (Lc '   list (e.g. read,bash,+codemode)' '   列表（例：read,bash,+codemode）') '') }
    ''  { }
    default { $script:Tools = $v }
  }

  $v = Ask (Lc 'd) Hide thinking blocks? [y/N] (blank = skip)' 'd) 隐藏思考块？[y/N]（留空=跳过）') ''
  switch ($v) {
    { $_ -match '^(y|yes)$' } { $script:HideThinking = 'on' }
    { $_ -match '^(n|no)$' }  { $script:HideThinking = 'off' }
  }

  Write-Host (Lc 'e) Quiet startup: 1) on  2) off  3) header only  (blank = skip)' 'e) 安静启动：1) 开启  2) 关闭  3) 仅保留头部（留空=跳过）')
  $v = Ask (Lc '   choose [1-3]' '   请选择 [1-3]') ''
  switch ($v) {
    '1' { $script:QuietStartup = 'on' }
    '2' { $script:QuietStartup = 'off' }
    '3' { $script:QuietStartup = 'header' }
    ''  { }
    default { $script:QuietStartup = $v }
  }

  Write-Host (Lc 'f) Cache warming: 1) streaming  2) idle  3) off  (blank = skip)' 'f) 缓存预热：1) streaming  2) idle  3) off （留空=跳过）')
  $v = Ask (Lc '   choose [1-3]' '   请选择 [1-3]') ''
  switch ($v) {
    '1' { $script:CacheWarming = 'streaming' }
    '2' { $script:CacheWarming = 'idle' }
    '3' { $script:CacheWarming = 'off' }
    ''  { }
    default { $script:CacheWarming = $v }
  }

  Write-Host (Lc 'g) Install a Pi package (e.g. npm:@foo/pi-tools or git:github.com/user/repo), blank = skip' 'g) 安装 Pi 包（例：npm:@foo/pi-tools 或 git:github.com/user/repo），留空=跳过')
  $v = Ask (Lc '   package source' '   包来源') ''
  while ($v) {
    $script:Package += $v
    $v = Ask (Lc '   another package (blank = done)' '   另一个包（留空=完成）') ''
  }

  Write-Host (Lc 'h) Add an MCP server (stdio or HTTP), blank = skip' 'h) 添加 MCP 服务器（stdio 或 HTTP），留空=跳过')
  $v = Ask (Lc '   server name' '   服务器名称') ''
  while ($v) {
    $cmd = Ask (Lc '   command (stdio, e.g. npx) or url (http)' '   命令（stdio，如 npx）或 url（http）') ''
    if ($cmd) {
      if ($cmd -match '^https?://') {
        $script:McpAdd += "$v={`"url`":`"$cmd`"}"
      } else {
        $argsLine = Ask (Lc '   arguments, space-separated (blank = none)' '   参数，空格分隔（留空=无）') ''
        $jsonArgs = '[]'
        if ($argsLine) {
          $escaped = $argsLine.Split(' ') | Where-Object { $_ } | ForEach-Object { '"' + ($_ -replace '\\','\\' -replace '"','\"') + '"' }
          $jsonArgs = '[' + ($escaped -join ',') + ']'
        }
        $script:McpAdd += "$v={`"command`":`"$cmd`",`"args`":$jsonArgs}"
      }
    }
    $v = Ask (Lc '   another server (blank = done)' '   另一个服务器（留空=完成）') ''
  }

  Write-Host (Lc 'i) Add persistent instructions for every project? (AGENTS.md), blank = skip' 'i) 添加适用于所有项目的持久指令？（AGENTS.md），留空=跳过')
  $v = Ask (Lc '   instructions' '   指令内容') ''
  if ($v) { $script:AgentsMd = $v }
}

function Invoke-Wizard {
  Write-Host ''
  Select-Language
  Ensure-Runtime
  Write-Host ''
  Info (Lc 'step-by-step setup (press Enter to accept the [default])' '逐步配置（直接回车 = 采用 [默认值]）')
  Write-Host ''

  if (-not $BaseUrl) { $BaseUrl = Ask (Lc '1) Endpoint base URL (e.g. https://api.example.com/v1)' '1) 接口 base URL（例：https://api.example.com/v1）') $null }
  if (-not $BaseUrl) { Die (Lc 'base URL is required' 'base URL 必填') }

  if (-not $ApiKey) {
    $k = Ask-Secret (Lc '2) API key' '2) API key')
    if ($k) { $ApiKey = $k }
  }
  if (-not $ApiKey) { Die (Lc 'API key is required' 'API key 必填') }

  if (-not $Models -and -not $ModelsFile) {
    Info (Lc 'fetching the model list from the endpoint...' '正在从端点获取模型列表...')
    $list = Get-RemoteModels
    if ($list) {
      Info (Lc "found $($list.Count) models" "共发现 $($list.Count) 个模型")
      $picked = Select-Models $list
      if ($picked) { $Models = $picked }
    } else {
      Warn (Lc 'falling back to typing model ids by hand' '改用手动输入模型 id')
    }
  }
  if (-not $Models -and -not $ModelsFile) {
    $Models = Ask (Lc '3) Model ids, comma-separated (e.g. gpt-4o,gpt-4o-mini)' '3) 模型 id，逗号分隔（例：gpt-4o,gpt-4o-mini）') $null
    if (-not $Models) { Die (Lc 'at least one model is required' '至少需要一个模型') }
  }

  $Provider = Ask (Lc '4) Provider name (blank = auto from host)' '4) Provider 名称（留空 = 由域名自动推导）') $Provider

  Write-Host (Lc '5) API protocol:  1) openai-completions (default)  2) openai-responses  3) anthropic-messages' '5) API 协议：1) openai-completions（默认） 2) openai-responses  3) anthropic-messages')
  $choice = Ask (Lc '   choose [1-3]' '   请选择 [1-3]') '1'
  switch ($choice) {
    '2' { $ApiType = 'openai-responses' }
    '3' { $ApiType = 'anthropic-messages' }
    '1' { $ApiType = 'openai-completions' }
    default { Warn (Lc "unknown choice '$choice', using openai-completions" "未知选项 '$choice'，改用 openai-completions"); $ApiType = 'openai-completions' }
  }

  Write-Host (Lc 'Where should the API key be stored?  1) models.json (default, simple)  2) auth.json (credential file, chmod 600)' 'API key 存在哪里？1) models.json（默认，简单）  2) auth.json（凭据文件，权限 600）')
  $choice = Ask (Lc '   choose [1-2]' '   请选择 [1-2]') '1'
  if ($choice -eq '2') { $script:AuthMode = 'auth' } else { $script:AuthMode = 'models' }

  $DefaultModel = Ask (Lc '6) Default model (blank = provider/<first model>)' '6) 默认模型（留空 = provider/<第一个模型>）') $DefaultModel

  Write-Host ''
  Info (Lc 'about to write:' '即将写入：')
  Write-Host "   Base URL : $BaseUrl"
  Write-Host "   API key  : $(Mask $ApiKey)"
  Write-Host "   Models   : $(if ($Models) { $Models } else { '(from file)' })"
  Write-Host "   Provider : $(if ($Provider) { $Provider } else { '(auto)' })"
  Write-Host "   Protocol : $ApiType"
  Write-Host "   Key store: $AuthMode"
  if (-not $NoDefault) { Write-Host "   Default  : $(if ($DefaultModel) { $DefaultModel } else { '(provider/<first model>)' })" }
  Write-Host ''
  if (-not (Ask-Yes (Lc '7) Write this config?' '7) 写入以上配置？') 'n')) { Info (Lc 'cancelled' '已取消'); exit 0 }

  if (-not $NoCustomize) {
    Write-Host ''
    if (Ask-Yes (Lc '8) Personalize settings now (theme / thinking / tools / packages)?' '8) 现在个性化设置（主题 / 推理档位 / 工具 / 包）？') 'n') {
      Invoke-CustomizeWizard
    }
  }
}

if (-not $SkipInstall) {
  $piBin = Find-Pi
  if ($piBin) {
    Info "pi already installed: $(& $piBin --version 2>$null) - checking for updates"
    Update-Pi $piBin
  } else {
    if (Ask-Yes (Lc 'Pi is not installed. Install it now?' 'Pi 尚未安装，现在安装？') 'y') {
      if (-not (Install-Pi)) { Die 'pi install failed; aborting' }
    }
    else { Die (Lc 'pi is required; aborting' 'pi 是必需的；已中止') }
    $piBin = Find-Pi
    if (-not $piBin) { Die 'pi installed but not found on PATH; open a new terminal and re-run' }
    Info "installed: $(& $piBin --version 2>$null)"
  }
} else {
  Info (Lc 'SkipInstall set, not checking installation' '已指定 SkipInstall，跳过安装检查')
}

$haveCustomizeFlags = $Theme -or $Thinking -or $Tools -or $HideThinking -or $QuietStartup -or $CacheWarming -or `
  $CacheMissNotices -or $CollapseChangelog -or $SkillCommands -or $EnabledModels -or $Compaction -or `
  $Steering -or $FollowUp -or $TuiMode -or $Editor -or $HttpProxy -or $SessionDir -or `
  $ProjectTrust -or $Telemetry -or $Analytics -or $AgentsMd -or $AppendSystem -or $SystemMd -or `
  $McpJson -or $KeybindingsJson -or $ModelsJson -or `
  $Package.Count -or $SetJson.Count -or $ModelThinking.Count -or $Extension.Count -or `
  $Skill.Count -or $PromptTemplate.Count -or $ThemeFile.Count -or $McpAdd.Count -or $Keybinding.Count
if ($Interactive) { Invoke-Wizard }
elseif ($BaseUrl -or $ApiKey -or $Models -or $ModelsFile) {
  if (-not $Models -and -not $ModelsFile) { Invoke-Wizard }
  if (-not $BaseUrl -or -not $ApiKey) { Invoke-Wizard }
}
elseif (-not $haveCustomizeFlags) { Invoke-Wizard }

$configArgs = @()
if ($BaseUrl -or $ApiKey -or $Models -or $ModelsFile -or $ModelsJson) {
  $configArgs += @('--base-url', $BaseUrl, '--api-key', $ApiKey)
  if ($ModelsJson) { $configArgs += @('--models-json', $ModelsJson) }
  elseif ($ModelsFile) { $configArgs += @('--models-file', $ModelsFile) }
  else { $configArgs += @('--models', $Models) }
}
$configArgs += @('--lang', $script:LangCode)
if ($Provider)     { $configArgs += @('--provider', $Provider) }
if ($ApiType)      { $configArgs += @('--api-type', $ApiType) }
if ($DefaultModel) { $configArgs += @('--default-model', $DefaultModel) }
if ($AuthMode)     { $configArgs += @('--auth-mode', $AuthMode) }
if ($NoDefault)    { $configArgs += '--no-default' }
if ($DryRun)       { $configArgs += '--dry-run' }
if (-not $NoCustomize) {
  if ($Theme -and $Theme -ne '__keep__') { $configArgs += @('--theme', $Theme) }
  if ($Thinking)      { $configArgs += @('--thinking', $Thinking) }
  if ($Tools -and $Tools -ne '__keep__') { $configArgs += @('--tools', $Tools) }
  if ($HideThinking)  { $configArgs += @('--hide-thinking', $HideThinking) }
  if ($QuietStartup)  { $configArgs += @('--quiet-startup', $QuietStartup) }
  if ($CacheWarming)  { $configArgs += @('--cache-warming', $CacheWarming) }
  if ($CacheMissNotices) { $configArgs += @('--cache-miss-notices', $CacheMissNotices) }
  if ($CollapseChangelog) { $configArgs += @('--collapse-changelog', $CollapseChangelog) }
  if ($SkillCommands) { $configArgs += @('--skill-commands', $SkillCommands) }
  if ($EnabledModels) { $configArgs += @('--enabled-models', $EnabledModels) }
  if ($Compaction)    { $configArgs += @('--compaction', $Compaction) }
  if ($Steering)      { $configArgs += @('--steering', $Steering) }
  if ($FollowUp)      { $configArgs += @('--follow-up', $FollowUp) }
  if ($TuiMode)       { $configArgs += @('--tui-mode', $TuiMode) }
  if ($Editor)        { $configArgs += @('--editor', $Editor) }
  if ($HttpProxy)     { $configArgs += @('--http-proxy', $HttpProxy) }
  if ($SessionDir)    { $configArgs += @('--session-dir', $SessionDir) }
  if ($ProjectTrust)  { $configArgs += @('--project-trust', $ProjectTrust) }
  if ($Telemetry)     { $configArgs += @('--telemetry', $Telemetry) }
  if ($Analytics)     { $configArgs += @('--analytics', $Analytics) }
  if ($McpJson)       { $configArgs += @('--mcp-json', $McpJson) }
  if ($KeybindingsJson) { $configArgs += @('--keybindings-json', $KeybindingsJson) }
  if ($AgentsMd)      { $configArgs += @('--agents-md', $AgentsMd) }
  if ($AppendSystem)  { $configArgs += @('--append-system', $AppendSystem) }
  if ($SystemMd)      { $configArgs += @('--system-md', $SystemMd) }
  foreach ($p in $Package) { $configArgs += @('--package', $p) }
  foreach ($j in $SetJson) { $configArgs += @('--set-json', $j) }
  foreach ($m in $ModelThinking) { $configArgs += @('--model-thinking', $m) }
  foreach ($x in $Extension) { $configArgs += @('--extension', $x) }
  foreach ($s in $Skill) { $configArgs += @('--skill', $s) }
  foreach ($pt in $PromptTemplate) { $configArgs += @('--prompt-template', $pt) }
  foreach ($tf in $ThemeFile) { $configArgs += @('--theme-file', $tf) }
  foreach ($ma in $McpAdd) { $configArgs += @('--mcp-add', $ma) }
  foreach ($kb in $Keybinding) { $configArgs += @('--keybinding', $kb) }
}

Ensure-Runtime
$configScript = Get-ConfigScript
Info (Lc 'writing config' '正在写入配置')
if (Get-Command node -ErrorAction SilentlyContinue) { & node $configScript @configArgs }
elseif (Get-Command bun -ErrorAction SilentlyContinue) { & bun $configScript @configArgs }
else { Die 'need node or bun to write pi config' }
if ($LASTEXITCODE -ne 0) { Die "config step failed (exit $LASTEXITCODE)" }

Write-Host ''
Info (Lc 'done. Start Pi with:' '完成。用以下命令启动 Pi：')
Write-Host '   cd path\to\project; pi'
Write-Host ('   ' + (Lc 'authenticate a built-in provider with /login inside Pi' '在 Pi 内用 /login 登录内置 provider'))
