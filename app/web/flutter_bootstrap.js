{{flutter_js}}
{{flutter_build_config}}

// The game needs the WebAssembly build (64-bit integers; docs K218).
// Flutter only picks it on Chromium by default: Safari 18.2+ and
// Firefox 120+ run it too.
_flutter.loader.load({
  config: {
    wasmAllowList: { blink: true, gecko: true, webkit: true },
  },
});
