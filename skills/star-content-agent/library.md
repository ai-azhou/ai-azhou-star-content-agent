# 数据目录、state.json 和收藏库

## 一、数据目录里有什么

数据目录的位置是固定的（见 SKILL.md「skill 目录和数据目录」），完整路径记在 state.json 的 `data_dir`。skill 目录是只读的，完整路径记在 `skill_dir`。

| 文件 | 是什么 | 谁来写 |
|---|---|---|
| `skill/` | 用安装包装的才有：这套规则、门卫脚本、js 页面脚本、LICENSE。用 npx 装的，这些在 Agent 自己的技能目录里 | 只读。更新时整体替换 |
| `state.json` | 设置和进度，从 skill 目录里的 `state.template.json` 复制出来 | 你 |
| `library.jsonl` | 收藏库，一行一条 | 你 |
| `site-notes.md` | 每个平台的读法笔记，只记结构 | 你 |
| `skip.txt` | 用户不想让 AI 看的关键词或作者，一行一个 | 你，按用户说的写 |
| `picks/` | 每天交付的结果，一天一个文件 | 你 |
| `tmp/` | 临时截图和 OpenCLI 的缓存，用完即删 | 你和门卫 |
| `gate/` | 门卫自己的记录（间隔、计数、暂停、锁） | 门卫。你只写其中三个文件：`opencli-path`、`profile`、`limit.<平台>` |
| `requests.log` | 每一次平台请求的记录 | 门卫 |
| `run.log` | 每次运行一行 | 你 |
| `怎么用.md` | 写给用户看的使用卡 | 你，设置结束时写 |
| `STOP` | 急停开关：有这个文件就不访问任何平台 | 用户要停时你建，要恢复时你删 |

## 二、state.json

字段以 skill 目录里的 `state.template.json` 为准，不要自己发明新的顶层字段。要点：

- `data_dir`、`skill_dir`、`install_method`：数据目录、skill 目录的完整路径，以及安装方式（`package` 或 `npx`）。

- `setup.next_step`：下一个还没做完的设置步骤（1–8），做完是 `done`。`setup.decisions` 记用户在第 0 步定下的特殊用法。
- `capabilities`：你能不能运行命令、看图、到点自己启动、无人值守。
- `platforms.<平台>`：
  - 收藏夹入口和账号名；
  - status：空、`blocked`（连续碰到风控，不再自动访问）、`off`；
  - `order_verified`：列表是不是确认按收藏时间从新到旧排；
  - `scan`：翻了多少条、有没有翻到底、哪天翻的；
  - `backfill_cursor`：旧收藏读到哪了；
  - `blocked_runs`、`redesign_fail_days`：连续碰到风控、连续读不出改版页面的次数。
- `prefs`：
  - 读法和图、帧的上限；
  - 读哪些（A / B / C 和筛选条件）；
  - 每天读多少（新、旧分开）；
  - 推送时间和推送方式；
  - 个性化主题卡。
- `schedule`：定时的方式、任务名或 ID、完整的启动命令、验收时间。
- `paused_until`：用户主动暂停到哪天。风控暂停记在门卫那里，不在这里。
- `last_run`、`last_delivery`：上次运行和上次交付的情况。

## 三、library.jsonl 每条记什么

**唯一键**是 `platform + id`：
- 小红书的 id 是笔记 id（24 位十六进制）；
- 抖音的 id 是视频 id（一串数字）。

不要把整条链接当 id。同一条内容的链接变了，只更新 url，不新增一行。

- **基本信息**：
  - platform、id、account（哪个账号收藏的）、title、author；
  - type：图文 / 视频；
  - url：最近一次在收藏列表里拿到的完整链接；url_seen：这条链接是哪天拿到的；
  - first_seen：第一次在收藏列表里看到的日期。这是看到的日期，不是收藏的日期；
  - saved_at：只有页面上明确写了收藏日期才填；
  - backfill：设置时就已经在收藏里的，记 true；
  - list_rank：设置时它在列表里的位置，数字越大越早，只能和同一个平台的条目比。
- **读取情况**：
  - read_state：pending（待读）/ done / failed；fail_count；
  - depth：title（只有标题）/ text（读了文字）/ visual（看了图或视频）；
  - read_at：哪天读的；
  - seen：看了多少，比如「图 3/9」「帧 4，视频 2:40」；
  - gaps：没读到或不确定的部分。
- **内容**：写给以后的你看，挑选时就靠这些，不再读原文。
  - summary：两三句话说清这条讲了什么；
  - points：最多 5 条要点；
  - quotes：0–3 句原话，一字不改，标明出处（正文 / 图 2 / 视频 01:23 字幕）。提示词要求「关联」必须引原话，以后不读原文，只能从这里引；
  - todo：如果 30 分钟内能照着做，用一句话写怎么做。只写用户自己动手就能做的事，不写命令、不写要登录、付款、下载的链接；做不了就留空；
  - topics：3–5 个主题词，方便找关联。
- **状态**：
  - status：ok / skipped（命中 skip.txt）/ suspect（让你拿不准是不是风控的条目）；
  - membership：saved / unsaved / unknown，以及 last_seen（最近一次在收藏列表里看到是哪天）；
  - availability：ok / deleted / link_stale / unknown，以及 last_check；
  - picked：哪几天被挑中过。

## 四、写的时候注意

- **用小脚本读写库**，不要把 library.jsonl 整份读进对话，也不要用编辑工具整份重写。
  - 先用 `node --version` 看有没有 node，有就用 node；
  - 没有 node，Mac 上可以用 python3，Windows 上用 PowerShell；
  - Windows 上不要直接敲 `python3`：没装 Python 时，它会打开微软应用商店。
- **按唯一键合并**：新的追加，已有的只改变了的字段。
- **防止写坏**：
  - 先写到同一个文件夹里的临时文件，检查每一行都是合法的 JSON、唯一键没有重复，再替换原文件；
  - 保留一份上一版（`library.jsonl.bak`、`state.json.bak`）；
  - state.json 读不出来时，用 .bak 恢复，不要当成新用户从头设置。
- **编码**：所有文件都用 UTF-8，不带 BOM。Windows PowerShell 5.1 里用 `[IO.File]::WriteAllText(路径, 内容, (New-Object Text.UTF8Encoding $false))`。`Out-File`、`>` 和 `Set-Content -Encoding utf8` 在那里都会写出别的编码，或者带 BOM。
- **skip.txt**：入库时先对一遍，命中的只记 platform、id 和 skipped，不存标题和内容。用户事后新加的，按 SKILL.md「以后别推这个作者」处理。
- **只在库写成功之后**，才推进 backfill_cursor 和读取队列。
