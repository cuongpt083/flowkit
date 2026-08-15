/**
 * Injected into MAIN world on labs.google — has access to window.grecaptcha
 * Also intercepts TRPC fetch responses to capture fresh signed media URLs.
 */
const SITE_KEY = '6LdsFiUsAAAAAIjVDZcuLhaHiDn5nnHVXVRQGeMV';

// ─── TRPC Response Monitor ─────────────────────────────────
// Monkey-patch fetch to intercept TRPC responses containing media URLs.
// Fresh signed GCS URLs are extracted and forwarded to the agent.

function _maybeForwardMediaBody(url, text) {
  if (!text || text.length < 20) return;
  if (
    text.includes('fifeUrl')
    || text.includes('encodedVideo')
    || text.includes('flow-content.google')
    || text.includes('ai-sandbox-videofx')
    || text.includes('/video/')
  ) {
    window.dispatchEvent(new CustomEvent('TRPC_MEDIA_URLS', {
      detail: { url: url || '', body: text },
    }));
  }
}

const _originalFetch = window.fetch;
window.fetch = async function (...args) {
  const response = await _originalFetch.apply(this, args);
  try {
    const url = typeof args[0] === 'string' ? args[0] : args[0]?.url || '';
    if ((url.includes('/fx/api/trpc/') || url.includes('aisandbox-pa.googleapis.com')) && response.ok) {
      const clone = response.clone();
      clone.text().then((text) => _maybeForwardMediaBody(url, text)).catch(() => {});
    }
  } catch {}
  return response;
};

const _xhrOpen = XMLHttpRequest.prototype.open;
const _xhrSend = XMLHttpRequest.prototype.send;
XMLHttpRequest.prototype.open = function (method, url, ...rest) {
  this.__fkUrl = url;
  return _xhrOpen.call(this, method, url, ...rest);
};
XMLHttpRequest.prototype.send = function (...args) {
  this.addEventListener('load', function () {
    try {
      const url = String(this.__fkUrl || '');
      if (url.includes('/fx/api/trpc/') || url.includes('aisandbox-pa.googleapis.com')) {
        _maybeForwardMediaBody(url, this.responseText || '');
      }
    } catch {}
  });
  return _xhrSend.apply(this, args);
};

// Visible clips in the Flow project UI often never hit TRPC intercept.
// Harvest signed media URLs from <video>/performance/HTML and forward them.
function _collectPageMediaUrls() {
  const found = [];
  const add = (u) => {
    if (typeof u === 'string' && u.startsWith('http') && !found.includes(u)) found.push(u);
  };
  try {
    document.querySelectorAll('video, source, img, a').forEach((el) => {
      add(el.currentSrc);
      add(el.src);
      add(el.poster);
      add(el.href);
    });
  } catch {}
  try {
    performance.getEntriesByType('resource').forEach((e) => add(e.name));
  } catch {}
  try {
    const html = document.documentElement ? document.documentElement.innerHTML : '';
    const re = /https:\/\/(?:flow-content\.google|storage\.googleapis\.com|lh3\.googleusercontent\.com)[^"'\\\s<>]+/g;
    let m;
    while ((m = re.exec(html))) add(m[0].replace(/&amp;/g, '&'));
  } catch {}
  return found.filter((u) =>
    /flow-content\.google|videofx|googleusercontent|\/video\/|\/image\/|\.mp4/i.test(u)
  );
}

let _lastPageMediaKey = '';
function _forwardPageMediaUrls() {
  const urls = _collectPageMediaUrls();
  if (!urls.length) return;
  const key = urls.slice().sort().join('|');
  if (key === _lastPageMediaKey) return;
  _lastPageMediaKey = key;
  window.dispatchEvent(new CustomEvent('TRPC_MEDIA_URLS', {
    detail: { url: location.href, body: urls.map((u) => JSON.stringify(u)).join(' ') },
  }));
}

[0, 1500, 4000, 8000, 15000].forEach((ms) => setTimeout(_forwardPageMediaUrls, ms));
try {
  const obs = new MutationObserver(() => {
    clearTimeout(window.__fkMediaScrapet);
    window.__fkMediaScrapet = setTimeout(_forwardPageMediaUrls, 800);
  });
  obs.observe(document.documentElement || document, { childList: true, subtree: true });
} catch {}


window.addEventListener('GET_CAPTCHA', async ({ detail }) => {
  const { requestId, pageAction } = detail;
  try {
    await waitForGrecaptcha();
    const token = await window.grecaptcha.enterprise.execute(SITE_KEY, {
      action: pageAction,
    });
    window.dispatchEvent(new CustomEvent('CAPTCHA_RESULT', {
      detail: { requestId, token },
    }));
  } catch (e) {
    window.dispatchEvent(new CustomEvent('CAPTCHA_RESULT', {
      detail: { requestId, error: e.message },
    }));
  }
});

function waitForGrecaptcha(timeout = 10000) {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const check = () => {
      if (window.grecaptcha?.enterprise?.execute) return resolve();
      if (Date.now() - start > timeout) return reject(new Error('grecaptcha not available'));
      setTimeout(check, 200);
    };
    check();
  });
}
