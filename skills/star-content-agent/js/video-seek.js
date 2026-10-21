(async () => {
  /* 跳到视频的某个比例处（参数 0–1）。静音、暂停状态下设好 currentTime，等跳过去；
     再静音播放一小下、暂停，逼播放器把这一帧真正画出来；能确认画出来时 frameShown 为 true。
     本文件不用双引号、不用双斜杠注释 */
  const f = Math.min(Math.max(__ARG__, 0), 0.98);
  const vids = [...document.querySelectorAll('video')];
  if (!vids.length) return { found: false };
  const area = v => { const r = v.getBoundingClientRect(); return r.width * r.height; };
  const v = vids.sort((a, b) => area(b) - area(a))[0];
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  v.muted = true;
  v.pause();
  if (!(v.duration > 0 && isFinite(v.duration))) return { found: true, ok: false, reason: 'duration unknown' };
  const target = v.duration * f;
  const seeked = new Promise(r => { v.addEventListener('seeked', () => r(true), { once: true }); setTimeout(() => r(false), 8000); });
  v.currentTime = target;
  const didSeek = await seeked;
  const frame = new Promise(r => {
    if (typeof v.requestVideoFrameCallback === 'function') { v.requestVideoFrameCallback(() => r(true)); setTimeout(() => r(false), 2500); }
    else { setTimeout(() => r(null), 600); }
  });
  try { await Promise.race([v.play(), sleep(2000)]); } catch (e) {}
  const frameShown = await frame;
  v.pause();
  for (let i = 0; i < 15 && v.readyState < 2; i++) await sleep(200);
  return { found: true, ok: didSeek && v.readyState >= 2, frameShown, target, currentTime: v.currentTime, readyState: v.readyState, muted: v.muted };
})()
