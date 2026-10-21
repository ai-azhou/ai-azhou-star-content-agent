(() => {
  /* 页面体检：只看平台自己给的信号（地址、验证码控件、登录状态），不看内容里的字；顺手把页面上的视频都静音。本文件不用双引号、不用双斜杠注释 */
  const href = location.href;
  const urlRisk = /website-login\/error|error_code=|captcha|verify|security/i.test(href);
  const captcha = !!document.querySelector(
    `[class*='captcha' i], [id*='captcha' i], [class*='geetest' i], [class*='slider-verify' i], [class*='verify-wrap' i], iframe[src*='captcha' i], iframe[src*='verify' i]`
  );
  const st = window.__INITIAL_STATE__ && window.__INITIAL_STATE__.user;
  const li = st ? st.loggedIn : undefined;
  const loggedIn = li == null ? null : (typeof li === 'object' ? (li._value ?? li.value ?? null) : li);
  const loginPage = /\/login(\b|\/|\?)/i.test(location.pathname + location.search) && !urlRisk;
  const videos = document.querySelectorAll('video');
  videos.forEach(v => { v.muted = true; });
  return { href, title: document.title, urlRisk, captcha, loggedIn, loginPage, videos: videos.length, textLength: (document.body ? document.body.innerText : '').length };
})()
