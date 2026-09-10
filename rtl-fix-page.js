;(function () {
  'use strict';
  if (typeof window === 'undefined' || window.__zcodeRtlApplied) return;
  window.__zcodeRtlApplied = true;

  // حباب پیام کاربر و بلوک‌های متنی ساده معمولاً div/span با white-space:pre-wrap
  // هستند و p/li نیستند؛ برای این‌ها dir="auto" می‌گذاریم (جهت + تراز، خودکار).
  // پیام‌های استریم‌شده جدید هم با MutationObserver پوشش داده می‌شوند.
  // مهم: ادیتور چت (textarea و contenteditable/Lexical) عمداً دست‌نخورده می‌ماند؛
  // ادیتور جهت را خودش مدیریت می‌کند و دخالت ما رفتارش را خراب می‌کرد.

  function inCode(el) {
    return !!(el.closest && el.closest('pre, code, kbd, samp, textarea, [contenteditable="true"], [contenteditable=""]'));
  }
  function okDisplay(el) {
    var d;
    try { d = window.getComputedStyle(el).display; } catch (e) { return true; }
    return !(d === 'flex' || d === 'grid' || d === 'inline-flex' || d === 'inline-grid');
  }
  function hasDirectText(el) {
    for (var n = el.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === 3 && n.data && n.data.trim()) return true;
    }
    return false;
  }
  function processElement(el) {
    if (el.hasAttribute('dir')) return;
    if (inCode(el)) return;
    if (!okDisplay(el)) return;
    el.setAttribute('dir', 'auto');
    // اگر محتوای این بلوک متنی غالباً فارسی است، برای فونت وزیرمتن تگ بزن
    var txt = el.textContent || '';
    if (countMatches(txt, RTL_RE) > 0 && countMatches(txt, RTL_RE) >= countMatches(txt, LATIN_RE)) {
      el.setAttribute('data-zcode-rtl', '1');
    }
  }

  // --- تشخیص غالب بودن فارسی برای عناصر متنی p/li/h* و مانند آن ---
  // plaintext جهت را از «اولین حرف قوی» می‌گیرد؛ آیتمی که با کلمه/کد انگلیسی شروع
  // می‌شود اما عمدتاً فارسی است، باید صریحاً RTL شود.
  var SEMANTIC = 'p, li, h1, h2, h3, h4, h5, h6, blockquote, td, th, figcaption, dd, dt, summary';
  var RTL_RE = /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/g;
  var LATIN_RE = /[A-Za-z]/g;

  function countMatches(s, re) {
    var m = s.match(re);
    return m ? m.length : 0;
  }
  function applyDirSemantic(el) {
    var txt = el.textContent || '';
    var arabic = countMatches(txt, RTL_RE);
    if (arabic === 0) {
      // فارسی ندارد؛ اگر قبلاً ما RTL کرده بودیم و متن انگلیسی شده، برگرد
      if (el.getAttribute('data-zcode-rtl') === '1') {
        el.removeAttribute('dir');
        el.removeAttribute('data-zcode-rtl');
        el.style.removeProperty('unicode-bidi');
      }
      return;
    }
    var latin = countMatches(txt, LATIN_RE);
    if (arabic >= latin) {
      if (el.getAttribute('data-zcode-rtl') === '1' && el.getAttribute('dir') === 'rtl') return;
      if (el.hasAttribute('dir') && el.getAttribute('data-zcode-rtl') !== '1') return; // dir واقعی اپ — دست نزن
      el.setAttribute('dir', 'rtl');
      el.setAttribute('data-zcode-rtl', '1');
      // plaintext استایل پچ را برای این عنصر غیرفعال کن تا direction صریح حاکم شود
      el.style.setProperty('unicode-bidi', 'isolate', 'important');
    } else if (el.getAttribute('data-zcode-rtl') === '1') {
      el.removeAttribute('dir');
      el.removeAttribute('data-zcode-rtl');
      el.style.removeProperty('unicode-bidi');
    }
  }

  function scan() {
    try {
      var sems = document.querySelectorAll(SEMANTIC);
      for (var q = 0; q < sems.length; q++) {
        if (inCode(sems[q])) continue;
        applyDirSemantic(sems[q]);
      }
      var ds = document.querySelectorAll('div, span');
      for (var j = 0; j < ds.length; j++) {
        var el = ds[j];
        if (el.hasAttribute('dir')) continue;
        if (!hasDirectText(el)) continue;
        if (inCode(el)) continue;
        var ws;
        try { ws = window.getComputedStyle(el).whiteSpace; } catch (e) { continue; }
        if (ws === 'pre-wrap' || ws === 'pre-line') processElement(el);
      }
    } catch (e) {}
  }

  var pending = false;
  function schedule() {
    if (pending) return;
    pending = true;
    setTimeout(function () { pending = false; scan(); }, 200);
  }

  function start() {
    scan();
    try {
      var obs = new MutationObserver(function (muts) {
        for (var i = 0; i < muts.length; i++) {
          if (muts[i].addedNodes && muts[i].addedNodes.length) { schedule(); return; }
        }
      });
      obs.observe(document.documentElement, { childList: true, subtree: true });
    } catch (e) {}
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
