// Before Flutter starts (docs K235).
(function () {
  // Flutter reads the browser's languages with Intl.Locale, which throws on
  // tags like "en-US@posix" and stops the game on the loading screen. Keep
  // only the tags it can read.
  function valid(tag) {
    try {
      new Intl.Locale(tag);
      return true;
    } catch (_) {
      return false;
    }
  }
  function clean(tag) {
    if (typeof tag !== 'string') return null;
    if (valid(tag)) return tag;
    var cut = tag.split(/[@.]/)[0].replace(/_/g, '-');
    return valid(cut) ? cut : null;
  }
  try {
    var raw = navigator.languages && navigator.languages.length
        ? Array.prototype.slice.call(navigator.languages)
        : [navigator.language];
    var langs = raw.map(clean).filter(function (t) { return t; });
    if (langs.length === 0) langs = ['en-US'];
    var changed = langs.length !== raw.length ||
        langs.some(function (t, i) { return t !== raw[i]; });
    if (changed) {
      Object.defineProperty(navigator, 'languages',
          { get: function () { return langs.slice(); }, configurable: true });
      Object.defineProperty(navigator, 'language',
          { get: function () { return langs[0]; }, configurable: true });
    }
  } catch (_) {}
})();

// A message on the loading screen instead of loading forever.
function mcsShow(en, tr, detail) {
  var box = document.getElementById('loading');
  if (!box || box.dataset.failed) return;
  box.dataset.failed = '1';
  var turkish = /^tr\b/i.test(navigator.language || '');
  var text = box.querySelector('div');
  text.textContent = turkish ? tr : en;
  text.style.cssText = 'max-width: 320px; text-align: center; line-height: 1.5; padding: 0 16px;';
  if (detail) {
    var d = document.createElement('div');
    d.textContent = detail;
    d.style.cssText = 'max-width: 320px; text-align: center; font-size: 11px; opacity: 0.6; padding: 0 16px; word-break: break-word;';
    box.appendChild(d);
  }
}

// The game needs the WebAssembly build with garbage collection (64-bit
// integers; docs K218): Chrome/Edge 119+, Firefox 120+, Safari 18.2+.
var mcsWasmGC = (function () {
  try {
    return typeof WebAssembly === 'object' && WebAssembly.validate(
        new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 95, 1, 120, 0]));
  } catch (_) {
    return false;
  }
})();

if (!mcsWasmGC) {
  mcsShow(
      'This browser is too old for the game. Update it or open the game in a recent Chrome, Edge, Firefox or Safari (iPhone: iOS 18.2 or later).',
      'Bu tarayıcı oyun için çok eski. Güncelle ya da oyunu güncel bir Chrome, Edge, Firefox veya Safari\'de aç (iPhone\'da iOS 18.2 ve sonrası).');
} else {
  // Anything that stops the start shows on the loading screen.
  var mcsFail = function (e) {
    if (!document.getElementById('loading')) return;
    var m = e && (e.reason || e.error || e.message);
    mcsShow(
        'The game could not start. Reload the page; if it keeps happening, send this message:',
        'Oyun açılamadı. Sayfayı yenile; tekrar olursa bu mesajı gönder:',
        String((m && m.message) || m || 'unknown error').slice(0, 300));
  };
  window.addEventListener('error', mcsFail);
  window.addEventListener('unhandledrejection', mcsFail);

{{flutter_js}}
{{flutter_build_config}}

  // Flutter only picks the WebAssembly build on Chromium by default:
  // Safari 18.2+ and Firefox 120+ run it too.
  _flutter.loader.load({
    config: {
      wasmAllowList: { blink: true, gecko: true, webkit: true },
    },
  });
}
