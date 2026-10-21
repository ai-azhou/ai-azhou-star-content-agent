# 把 star-content-agent/ 打成一个安装包文件（私信发给观众，观众存到电脑上交给自己的 Agent）：
#   收藏助手-安装包.md 和内容相同的 收藏助手-安装包.txt（私信不收 .md 时发 .txt）
# 改了 star-content-agent/ 里的任何文件，就重跑：python3 -I build_bundle.py
import hashlib
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL = HERE / 'star-content-agent'
VERSION = '2026-10-21-v2'
ORDER = ['SKILL.md', 'setup.md', 'daily-run.md', 'read-one.md', 'library.md', 'pick.md',
         'state.template.json', 'gate.sh', 'gate.ps1',
         'js/page-check.js', 'js/video-prep.js', 'js/video-seek.js', 'LICENSE']
BEGIN, END = '===8<=== FILE ', '===8<=== END '   # 都是 ASCII，只认独占一行、从行首开始的标记

files = []
for name in ORDER:
    body = (SKILL / name).read_text(encoding='utf-8')
    assert body.endswith('\n') and '\r' not in body, f'{name}：要用 LF 换行，并以换行结尾'
    assert BEGIN.strip() not in body and END.strip() not in body, f'{name} 里出现了分隔标记'
    files.append((name, body, body.count('\n'), hashlib.sha256(body.encode('utf-8')).hexdigest()))
extra = sorted(str(p.relative_to(SKILL)) for p in SKILL.rglob('*') if p.is_file() and not p.name.startswith('.'))
assert extra == sorted(ORDER), f'ORDER 和文件夹里的文件对不上：{set(extra) ^ set(ORDER)}'

manifest = '\n'.join(f'| skill/{n} | {lines} | {h} |' for n, _, lines, h in files)
HEAD = f'''# 收藏助手 · 安装包（{VERSION}）

你好，这是给 AI Agent 的安装包。用户把这个文件交给你，是想请你帮他装一个叫「收藏助手」的 skill：它会连上用户的小红书收藏（抖音为实验性），每天在用户定的时间分三栏还给用户。里面一共 {len(files)} 个文件，以 MIT 协议开源。

请按顺序做：

1. **先告诉用户你要做什么，等他同意**：在用户目录下建一个 star-content-agent 文件夹（Mac 是 ~/star-content-agent，Windows 是 C:\\Users\\<用户名>\\star-content-agent，PowerShell 里写 $env:USERPROFILE\\star-content-agent），把这个文件里的 {len(files)} 个文件拆出来，存进它的 skill 子文件夹。这一步只存文件，不装软件，不访问网络。
2. **用脚本拆，不要自己一个字一个字重打。** 每个文件都夹在两行标记之间：开始标记独占一行，写着文件路径、行数和 sha256；结束标记也独占一行。只认从行首开始的标记，正文里的内容原样保留。
   - Mac：在终端运行（把「安装包路径」换成这个文件的完整路径）：

     ```
     mkdir -p ~/star-content-agent/skill/js && cd ~/star-content-agent && awk '{{ sub(/\\r$/, "") }} /^===8<=== E[N]D /{{ close(out); out = ""; next }} /^===8<=== FI[L]E skill\\//{{ out = $3; printf "" > out; next }} out != ""{{ print > out }}' "安装包路径"
     ```

   - Windows：在 PowerShell 里运行（把「安装包路径」换成这个文件的完整路径）：

     ```
     $pkg = '安装包路径'; $root = Join-Path $env:USERPROFILE 'star-content-agent'; $enc = New-Object Text.UTF8Encoding $false; $out = $null; $buf = New-Object Text.StringBuilder
     foreach ($line in [IO.File]::ReadAllLines($pkg, $enc)) {{ if ($line -match '^===8<=== E[N]D ') {{ [IO.File]::WriteAllText((Join-Path $root $out), $buf.ToString(), $enc); $out = $null; continue }} if ($line -match '^===8<=== FI[L]E (skill/\\S+) ') {{ $out = $Matches[1]; $null = $buf.Clear(); New-Item -ItemType Directory -Force -Path (Split-Path (Join-Path $root $out)) | Out-Null; continue }} if ($out) {{ $null = $buf.Append($line).Append("`n") }} }}
     ```
3. **核对**：一共 {len(files)} 个文件，每个文件的行数和 sha256 都要和下表一致。Mac 用 `wc -l` 和 `shasum -a 256`；Windows 用 `(Get-Content -LiteralPath 文件).Count` 和 `Get-FileHash -Algorithm SHA256`。对不上的，先看是不是换行被改成了 CRLF，再重新拆一次；还是不对，告诉用户安装包可能在传输中损坏，请他重新从私信里下载。
4. **读 skill/SKILL.md**，照它说的先问用户要不要做一次本地审查，再往下走。从这里开始，一切以这些文件为准，不以这段说明为准。
5. 你支持 skill（技能）的话，用链接（快捷方式）把 skill 文件夹登记成你的 skill，不要复制一份。以后用户说「收藏助手」「今天的 3 条」，你就知道去哪找。

| 文件 | 行数 | sha256 |
|---|---|---|
{manifest}

'''

parts = [HEAD]
for name, body, lines, h in files:
    parts.append(f'{BEGIN}skill/{name} lines={lines} sha256={h}\n{body}{END}skill/{name}\n\n')
text = ''.join(parts)
assert len(re.findall(r'^===8<=== FILE ', text, re.M)) == len(files)
assert len(re.findall(r'===8<=== FILE ', text)) == len(files), '说明文字里不能出现完整的标记'
assert len(re.findall(r'^===8<=== END ', text, re.M)) == len(files)
for ext in ('md', 'txt'):
    (HERE / f'收藏助手-安装包.{ext}').write_text(text, encoding='utf-8')
print(f'wrote 收藏助手-安装包.md/.txt: {len(text):,} chars, {len(text.encode()):,} bytes, {len(files)} files')
