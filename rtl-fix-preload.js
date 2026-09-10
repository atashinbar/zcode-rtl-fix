;(function () {
  'use strict';
  if (typeof window === 'undefined' || window.__zcodeRtlApplied) return;
  window.__zcodeRtlApplied = true;

  var CSS = [
    'p, li, h1, h2, h3, h4, h5, h6, blockquote, td, th, figcaption, dd, dt, summary { unicode-bidi: plaintext !important; }',
    'p, li, h1, h2, h3, h4, h5, h6, blockquote, td, th, figcaption, dd, dt, summary { text-align: start; }'
  ].join('\n');

  // ترجیح: webFrame.insertCSS (در سطح مرورگر، مستقل از CSP صفحه). جایگزین: تزریق <style>
  try {
    var electron = require('electron');
    if (electron && electron.webFrame && electron.webFrame.insertCSS) {
      electron.webFrame.insertCSS(CSS, { cssOrigin: 'author' });
    }
  } catch (e) {}

  var SEMANTIC = 'p, li, h1, h2, h3, h4, h5, h6, blockquote, td, th, figcaption, dd, dt, summary';

  function inCode(el) {
    return !!(el.closest && el.closest('pre, code, kbd, samp, textarea, [contenteditable="true"], [contenteditable=""]'));
  }
  function okDisplay(el) {
    try {
      var d = window.getComputedStyle(el).display;
      if (d === 'flex' || d === 'grid' || d === 'inline-flex' || d === 'inline-grid') return false;
    } catch (e) {}
    return true;
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
  }

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
      if (el.hasAttribute('dir') && el.getAttribute('data-zcode-rtl') !== '1') return;
      el.setAttribute('dir', 'rtl');
      el.setAttribute('data-zcode-rtl', '1');
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
      var list = document.querySelectorAll(SEMANTIC);
      for (var i = 0; i < list.length; i++) processElement(list[i]);
      // پیام‌های متنی ساده (user bubble) معمولاً div/span با white-space:pre-wrap هستند
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

  function injectStyleFallback() {
    try {
      var s = document.createElement('style');
      s.setAttribute('data-zcode-rtl', '1');
      s.textContent = CSS;
      (document.head || document.documentElement).appendChild(s);
    } catch (e) {}
  }

  function start() {
    injectStyleFallback();
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
