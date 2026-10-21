(async () => {
  /* 跳到视频的某个比例处（参数 0–1），保持静音暂停，等画面真的跳过去再返回（最多 6 秒）。本文件不用双引号、不用双斜杠注释 */
  const f = Math.min(Math.max(__ARG__, 0), 0.98);
  const vids = [...document.querySelectorAll('video')];
  if (!vids.length) return { found: false };
  const area = v => { const r = v.getBoundingClientRect(); return r.width * r.height; };
  const v = vids.sort((a, b) => area(b) - area(a))[0];
  v.muted = true;
  v.pause();
  if (!(v.duration > 0 && isFinite(v.duration))) return { found: true, ok: false, reason: 'duration unknown' };
  const target = v.duration * f;
  const seeked = new Promise(r => { v.addEventListener('seeked', () => r(true), { once: true }); setTimeout(() => r(false), 6000); });
  v.currentTime = target;
  const ok = await seeked;
  for (let i = 0; i < 15 && v.readyState < 2; i++) await new Promise(r => setTimeout(r, 200));
  return { found: true, ok: ok && v.readyState >= 2, target, currentTime: v.currentTime, readyState: v.readyState, muted: v.muted };
})()
