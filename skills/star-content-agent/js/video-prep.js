(async () => {
  /* 找到页面上最大的视频：静音，短暂播放一下再暂停（很多播放器要播过一次才会去掉封面层），读出时长。
     本文件不用双引号、不用双斜杠注释，方便压成一行传参 */
  const vids = [...document.querySelectorAll('video')];
  if (!vids.length) return { found: false };
  const area = v => { const r = v.getBoundingClientRect(); return r.width * r.height; };
  const v = vids.sort((a, b) => area(b) - area(a))[0];
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  v.muted = true;
  for (let i = 0; i < 25 && !(v.duration > 0 && isFinite(v.duration)); i++) await sleep(200);
  try { await Promise.race([v.play(), sleep(2000)]); } catch (e) {}
  await sleep(400);
  v.pause();
  return { found: true, count: vids.length, muted: v.muted, paused: v.paused, duration: v.duration, readyState: v.readyState, currentTime: v.currentTime };
})()
