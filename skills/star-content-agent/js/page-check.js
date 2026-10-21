(() => {
  /* 页面体检：只看平台自己给的信号（地址、验证码控件、登录状态），不看内容里的字；顺手把页面上的视频都静音。
     notFound（404 页，内容删了或链接失效）和 urlRisk（风控跳转）分开报：404 页的地址里也带 error_code，不能当风控。
     本文件不用双引号、不用双斜杠注释 */
  const href = location.href;
  const path = location.pathname;
  const qs = new URLSearchParams(location.search);
  const notFound = /^\/404(\/|$)/.test(path);
  const urlRisk = !notFound && /website-login\/error|captcha|verify|security-check/i.test(href);
  const captcha = !!document.querySelector(
    `[class*='captcha' i], [id*='captcha' i], [class*='geetest' i], [class*='slider-verify' i], [class*='verify-wrap' i], iframe[src*='captcha' i], iframe[src*='verify' i]`
  );
  const st = window.__INITIAL_STATE__ && window.__INITIAL_STATE__.user;
  const li = st ? st.loggedIn : undefined;
  const loggedIn = li == null ? null : (typeof li === 'object' ? (li._value ?? li.value ?? null) : li);
  const loginPage = /\/login(\b|\/|\?)/i.test(path + location.search) && !urlRisk && !notFound;
  const videos = document.querySelectorAll('video');
  videos.forEach(v => { v.muted = true; });
  return {
    href, title: document.title, notFound, urlRisk, captcha, loggedIn, loginPage,
    errorCode: qs.get('error_code') || '', errorMsg: qs.get('error_msg') || '',
    videos: videos.length, textLength: (document.body ? document.body.innerText : '').length
  };
})()
