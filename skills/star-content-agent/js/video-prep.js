(async () => {
  /* 找到页面上最大的视频：静音、暂停，等到能读出时长（最多 5 秒）。本文件不用双引号、不用双斜杠注释，方便压成一行传参 */
  const vids = [...document.querySelectorAll('video')];
  if (!vids.length) return { found: false };
  const area = v => { const r = v.getBoundingClientRect(); return r.width * r.height; };
  const v = vids.sort((a, b) => area(b) - area(a))[0];
  v.muted = true;
  v.pause();
  for (let i = 0; i < 25 && !(v.duration > 0 && isFinite(v.duration)); i++) await new Promise(r => setTimeout(r, 200));
  return { found: true, count: vids.length, muted: v.muted, paused: v.paused, duration: v.duration, readyState: v.readyState };
})()
