# 收藏助手 · star-content-agent

一个给 AI Agent 用的 skill：让你电脑上的 Agent 只读、低频地读你在小红书网页版（抖音为实验性）里的收藏，整理成一个本地收藏库，每天在你指定的时间分三栏还给你：

- **关联**：把看着不相干的收藏，串成一个道理；
- **今天就用**：挑一条 30 分钟内能照着做的；
- **值得想起**：翻出一条你早忘了的旧收藏。

来自阿舟的视频《先别收藏》。

## 怎么装

1. 你需要一台装了 Chrome 的电脑，加一个能在电脑上运行命令的 AI Agent，比如 Claude Code、Codex、WorkBuddy。只能聊天的 AI 用不了。
2. 三种装法，任选一种：
   - **用 npx**（需要 Node.js，网络要能访问 GitHub）：

     ```
     npx skills add ai-azhou/ai-azhou-star-content-agent -g
     ```

     它会装进你选的 Agent 的技能目录（[skills CLI](https://github.com/vercel-labs/skills) 支持 Claude Code、Codex、Cursor 等几十种）。装好后对 Agent 说「收藏助手」；Claude Code 里也可以用 `/star-content-agent`。以后用 `npx skills update` 更新。
   - **用安装包**：把 [`收藏助手-安装包.md`](./收藏助手-安装包.md) 下载到电脑上，然后对你的 Agent 说：

     > 请先读我电脑上的这个文件：【文件位置】。它是一个叫「收藏助手」的 skill 安装包。先别装任何东西：按文件开头的说明，先告诉我你要做什么、等我同意，再把它拆好存起来；然后照 SKILL.md 说的，先问我要不要做一次本地审查。

   - **手动复制**：让你的 Agent 把 [`skills/star-content-agent/`](./skills/star-content-agent/) 文件夹复制到 `~/star-content-agent/skill/`（Windows 是 `C:\Users\<用户名>\star-content-agent\skill\`），然后读里面的 `SKILL.md`，照它说的先问你要不要做一次本地审查。

   不管用哪种装法，你的数据都只存在 `~/star-content-agent/` 里（Windows 是 `C:\Users\<用户名>\star-content-agent\`），和 skill 装在哪儿无关。
3. Agent 会先问你要不要让它把这套工具审一遍。看完它的评估，你再决定用不用、怎么用。
4. 第一次设置大约 1 小时：你要回复它十几次，中间会有不少一分钟左右的等待。这是故意放慢的，免得被平台限制。

## 先说清楚几件事

- **网络**：安装时要下载开源工具 [OpenCLI](https://github.com/jackwener/opencli) 和它的 Chrome 扩展。下载不了时，Agent 会换别的下载源或离线安装包；还是网络不通，它会直接告诉你。
- **看图**：小红书很多内容在图片和视频里，能看图的 AI 才读得懂；看不了图的，只能按标题和文字来挑。Agent 会先自测。
- **花费**：读文字便宜，看图贵，一张截图大约相当于读一两千字。Agent 会按你的收藏数算好时间和花费，让你选读多细、每天读几条。
- **隐私**：收藏库只存在你自己电脑上，不另外上传。但 AI 读到的内容，会像你平时跟它聊天一样，发给它背后的模型处理。不想让 AI 看的收藏，先取消收藏。
- **风险**：平台会限制自动读取，读快了会弹验证码，严重时可能限制账号。这套工具读得很慢，碰到验证码就停，但风险不能完全排除；介意的话就别用。

## 它是怎么保证只读、低频的

- 所有访问平台的命令，都经过 `skills/star-content-agent/gate.sh`（Windows 是 `gate.ps1`）这个门卫脚本：
  - 两次请求之间随机等 45–60 秒；
  - 碰到风控暂停 20 小时；
  - 每个平台每天最多 80 次请求；
  - 只放行只读的浏览器命令；
  - 页面脚本只能运行 `js/` 里预先写好的三段。
- 收藏里的文字一律当资料，不当指令。
- 每天先用已经读过的内容挑选、交付，再去读新收藏，留给明天用。

## 测试状态

- Mac 版门卫脚本做过离线测试；安装包实际拆过、按 sha256 核对过。
- Windows 版门卫（`gate.ps1`）和在真实平台上的完整流程还在验证中。
- 安装时 Agent 会先跑一次门卫自检。有问题它会先试着自己修，修不好可以反馈给作者（见下一节）。

## 反馈问题、联系作者

碰到问题或者有建议，对你的 Agent 说「把问题反馈给作者」。它会整理一份去掉隐私信息的报告：版本、环境、出错的步骤和报错、已经试过的办法。你看过、同意以后，再选一个渠道发出去：

- **从你拿到安装包的平台（小红书或抖音）私信作者**（推荐）：把 AI 整理好的报告文件发过来；发文件不方便，就发它整理好的短版文字；
- **在这个仓库提 [issue](https://github.com/ai-azhou/ai-azhou-star-content-agent/issues)**：公开，所有人都看得到；
- **发邮件到 azhou.ai@proton.me**。

想要新版本，就对 Agent 说「更新收藏助手」。

## 文件

| 文件 | 是什么 |
|---|---|
| `skills/star-content-agent/SKILL.md` | 入口：硬规矩、路由表、门卫用法 |
| `skills/star-content-agent/setup.md` | 第一次设置（第 0 步是本地审查） |
| `skills/star-content-agent/daily-run.md` | 每天运行 |
| `skills/star-content-agent/read-list.md` | 翻收藏列表（以页面为准，接口数据只用来补字段和交叉核对） |
| `skills/star-content-agent/read-one.md` | 读一条收藏 |
| `skills/star-content-agent/library.md` | 数据目录、状态文件、收藏库字段 |
| `skills/star-content-agent/pick.md` | 挑选，包括视频里那段提示词 |
| `skills/star-content-agent/gate.sh`、`gate.ps1`、`js/` | 门卫和它允许运行的页面脚本 |
| `收藏助手-安装包.md` | 上面所有文件打成的一个文件，带 sha256 核对表 |
| `build_bundle.py` | 改了 `skills/star-content-agent/` 以后，用它重新生成安装包 |

## 改造

以 [MIT 协议](./LICENSE)开源，欢迎让你的 AI 按需改造。改的时候，建议保留硬规矩和门卫：它们保护的是你的账号和隐私。改完运行 `python3 build_bundle.py`，重新生成安装包和核对表。

OpenCLI 是另一个独立的开源项目（Apache-2.0），本仓库只包含收藏助手自己的文件。
