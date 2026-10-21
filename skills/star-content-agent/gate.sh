#!/bin/bash
# 收藏助手的门卫（Mac / Linux）。所有访问平台的 opencli browser 命令都经它发出：
# 它负责控频、风控暂停、急停、每天请求上限、命令白名单，并把 OpenCLI 的缓存留在数据目录里。
# 数据目录固定是 ~/star-content-agent（设了 STAR_CONTENT_AGENT_HOME 就用它），和这个脚本装在哪儿无关。
#
#   gate.sh <平台> <browser 子命令> [参数...]   例：gate.sh xhs open "https://..." --session sca-fav
#   gate.sh <平台> pace                          只等够请求间隔并记一次请求（点开会加载新内容的标签前用）
#   gate.sh pause <平台> <原因>                  碰到风控：暂停这个平台 20 小时
#   gate.sh unpause <平台>                       用户明确要求时才用
#   gate.sh lock <run_id> [--take-stale] | unlock <run_id> | status
#
# 退出码：0 成功（其余照 opencli 原样返回）；10 急停；11 平台暂停中；12 今天的请求到上限；
#         13 命令不在白名单；14 用法错误；15 另一次运行正在进行；16 还没等够，原样再运行一次同一条命令

set -u
SKILL_DIR=$(cd "$(dirname "$0")" && pwd)
DATA="${STAR_CONTENT_AGENT_HOME:-$HOME/star-content-agent}"
G="$DATA/gate"
mkdir -p "$G" "$DATA/tmp"

MIN_GAP=45; MAX_GAP=60        # 两次请求之间的随机间隔（秒）
ACTION_GAP=2                  # 页面里两步操作之间至少隔几秒
PAUSE_HOURS=20                # 风控暂停时长：到第二天同一时间的定时运行时已解除
DEFAULT_LIMIT=80              # 每个平台每天最多请求次数，可在 gate/limit.<平台> 里改
MAX_WAIT=$(cat "$G/max-wait" 2>/dev/null || echo 55)   # 单次调用最多等多久，防止撞上工具超时

now() { date +%s; }
say() { echo "[gate] $*" >&2; }
log() { echo "$(date '+%Y-%m-%dT%H:%M:%S%z') $*" >> "$DATA/requests.log"; }
usage() { sed -n '4,9p' "$0" >&2; exit 14; }
fmt() { date -r "$1" '+%m-%d %H:%M' 2>/dev/null || date -d "@$1" '+%m-%d %H:%M'; }

[ $# -ge 1 ] || usage

case "$1" in
  lock)
    [ $# -ge 2 ] || usage
    if mkdir "$G/lock" 2>/dev/null; then
      echo "$2 $(now)" > "$G/lock/owner"; say "已加锁：$2"; exit 0
    fi
    read -r owner started < "$G/lock/owner" 2>/dev/null || { owner=?; started=0; }
    age=$(( $(now) - ${started:-0} ))
    if [ "${3:-}" = "--take-stale" ] && [ "$age" -gt 10800 ]; then
      echo "$2 $(now)" > "$G/lock/owner"; say "接管了 ${age} 秒前的旧锁（${owner}）"; exit 0
    fi
    say "另一次运行（${owner}）在 ${age} 秒前开始，还没结束"; exit 15 ;;
  unlock)
    [ $# -ge 2 ] || usage
    read -r owner _ < "$G/lock/owner" 2>/dev/null || owner=""
    if [ "$owner" = "$2" ]; then rm -f "$G/lock/owner"; rmdir "$G/lock"; say "已解锁：$2"; exit 0; fi
    say "锁不属于 $2（现在是：${owner:-没有锁}）"; exit 14 ;;
  pause)
    [ $# -ge 3 ] || usage
    until_ts=$(( $(now) + PAUSE_HOURS * 3600 ))
    echo "$until_ts ${*:3}" > "$G/pause.$2"
    log "$2 pause ${*:3}"; say "$2 暂停到 $(fmt "$until_ts")"; exit 0 ;;
  unpause)
    [ $# -ge 2 ] || usage
    rm -f "$G/pause.$2"; log "$2 unpause"; say "$2 已解除暂停"; exit 0 ;;
  status)
    [ -f "$DATA/STOP" ] && echo "急停：开着（数据目录里有 STOP 文件）"
    [ -d "$G/lock" ] && echo "运行锁：$(cat "$G/lock/owner" 2>/dev/null)"
    for f in "$G"/pause.*; do [ -f "$f" ] || continue
      read -r u r < "$f"; p=${f##*/pause.}
      if [ "$u" -gt "$(now)" ]; then echo "$p 暂停到 $(fmt "$u")：$r"; else echo "$p 暂停已到期"; fi
    done
    for f in "$G"/count.*."$(date +%Y%m%d)"; do [ -f "$f" ] || continue
      p=${f#"$G"/count.}; echo "${p%%.*} 今天已请求 $(cat "$f") 次"; done
    exit 0 ;;
esac

# ---- 平台命令 ----
[ $# -ge 2 ] || usage
P="$1"; SUB="$2"; shift 2
case "$P" in *[!a-z0-9-]*|"") say "平台名只能用小写字母、数字和横线"; exit 14 ;; esac

# close 只是收尾（关掉自己开的标签页），急停和暂停期间也放行
if [ "$SUB" != "close" ]; then
  [ -f "$DATA/STOP" ] && { say "急停开着（数据目录里有 STOP 文件），不访问平台"; exit 10; }
  if [ -f "$G/pause.$P" ]; then
    read -r u r < "$G/pause.$P"
    if [ "${u:-0}" -gt "$(now)" ]; then say "$P 暂停中，到 $(fmt "$u")：$r"; exit 11; fi
  fi
fi

# 分类：request = 算一次请求（45–60 秒间隔、计数）；action = 页面里的操作；free = 只读当前页面
case "$SUB" in
  open|scroll|pace) KIND=request ;;
  click|eval|screenshot) KIND=action ;;
  state|find|get|extract|network|close|frames) KIND=free ;;
  wait)
    [ "${1:-}" = "time" ] && { say "不要用 wait time 等待：它页面一安静就返回。控频交给 gate"; exit 13; }
    KIND=free ;;
  *) say "不允许的子命令：$SUB"; exit 13 ;;
esac

if [ "$SUB" != "pace" ]; then
  case " $* " in *" --session sca-"*) ;; *) say "必须带 --session，名字以 sca- 开头"; exit 14 ;; esac
fi

# eval 只能跑 skill/js 里预先写好的脚本：gate.sh xhs eval @video-seek 0.4 --session sca-read
if [ "$SUB" = "eval" ]; then
  name=${1:-}; case "$name" in @[a-z-]*) ;; *) say "eval 只能用 @脚本名，见 skill/js/"; exit 13 ;; esac
  js="$SKILL_DIR/js/${name#@}.js"; [ -f "$js" ] || { say "没有这个脚本：$name"; exit 13; }
  shift; arg=0
  case "${1:-}" in ""|--*) ;; *) arg=$1; shift ;; esac
  case "$arg" in *[!0-9.]*) say "eval 参数只能是数字"; exit 14 ;; esac
  set -- "$(sed "s/__ARG__/$arg/g" "$js")" "$@"
fi

# 截图必须存成数据目录 tmp/ 里的 .png 文件，不然整张图会以 base64 文字打进对话
if [ "$SUB" = "screenshot" ]; then
  case "${1:-}" in "$DATA/tmp/"*.png) ;; *) say "截图要写成 $DATA/tmp/<名字>.png 这样的完整路径，放在第一个参数"; exit 14 ;; esac
fi

# 每天上限
if [ "$KIND" = request ]; then
  cf="$G/count.$P.$(date +%Y%m%d)"; c=$(cat "$cf" 2>/dev/null || echo 0)
  limit=$(cat "$G/limit.$P" 2>/dev/null || echo "$DEFAULT_LIMIT")
  [ "$c" -ge "$limit" ] && { say "$P 今天已请求 $c 次，到上限 ${limit}，留到明天"; exit 12; }
fi

# 控频
if [ "$KIND" = request ]; then
  last=$(cat "$G/last.$P" 2>/dev/null || echo 0)
  gap=$(cat "$G/gap.$P" 2>/dev/null || echo $(( MIN_GAP + RANDOM % (MAX_GAP - MIN_GAP + 1) )))
  echo "$gap" > "$G/gap.$P"
  remain=$(( last + gap - $(now) ))
  if [ "$remain" -gt "$MAX_WAIT" ]; then
    sleep "$MAX_WAIT"; say "还要再等 $(( remain - MAX_WAIT )) 秒，原样再运行一次同一条命令"; exit 16
  fi
  [ "$remain" -gt 0 ] && sleep "$remain"
  now > "$G/last.$P"; rm -f "$G/gap.$P"
  echo $(( c + 1 )) > "$cf"
elif [ "$KIND" = action ]; then
  la=$(cat "$G/action.$P" 2>/dev/null || echo 0)
  r=$(( la + ACTION_GAP - $(now) )); [ "$r" -gt 0 ] && sleep "$r"
  now > "$G/action.$P"
fi
log "$P $SUB $KIND"
[ "$SUB" = "pace" ] && exit 0

# 调 opencli
OC=$(cat "$G/opencli-path" 2>/dev/null || command -v opencli || true)
[ -n "$OC" ] || { say "找不到 opencli。设置时把它的完整路径写进 $G/opencli-path"; exit 14; }
export OPENCLI_CACHE_DIR="$DATA/tmp/opencli-cache" OPENCLI_WINDOW=background OPENCLI_BROWSER_IDLE_TIMEOUT=600
extra=()
case " $* " in *" --window "*) ;; *) extra+=(--window background) ;; esac
if [ -f "$G/profile" ]; then case " $* " in *" --profile "*) ;; *) extra+=(--profile "$(cat "$G/profile")") ;; esac; fi

if [ "$SUB" = "close" ]; then
  OPENCLI_CLOSE_OWNED_TAB=1 "$OC" browser close "$@" ${extra[@]+"${extra[@]}"} && exit 0
  "$OC" browser close "$@" ${extra[@]+"${extra[@]}"}; exit $?
fi
"$OC" browser "$SUB" "$@" ${extra[@]+"${extra[@]}"}
