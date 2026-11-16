# Capability bench

A self-contained page that probes the web viewer feature by feature. Serve it and drive it;
each section writes its findings as JSON into its own `<output>` element.

```
serve {"action":"start","server":"tools","root":"bench"}
browse {"url":"http://127.0.0.1:<port>/","output":"snapshot"}
```

Stop it afterwards with `serve {"action":"stop","server":"tools"}`.

## What each section proves

| # | Section | Proves |
|---|---|---|
| 1 | Form controls | select / checkbox / radio / range / date / file / disabled inputs are exposed in `snapshot`; checkbox and radio accept `click`; **`<select>` does not** (see workaround below) |
| 2 | Keyboard focus order | whether `press Tab` moves focus (it does not — `focusLog` stays `—`) |
| 3 | Frames | same-origin iframe readable via `eval`; cross-origin iframe blocked; iframe internals never appear in `snapshot` |
| 4 | Shadow DOM | a button inside `attachShadow({mode:'open'})` is visible to `snapshot` and clickable by the tool (counter reaches 2) |
| 5 | Canvas | `toDataURL('image/png')` works from page context |
| 6 | Storage | `localStorage` and cookies survive a reload |
| 7 | Network in-page | `fetch()` leaves the device and parses the response (GitHub's rate limiter answers 403 for this IP — still a successful round trip) |
| 8 | Downloads & dialogs | `confirm()` is auto-dismissed returning `false` without hanging; `window.open()` is blocked; `<a download>` has no observable effect |
| 9 | Visibility | `display:none` is excluded from `## content`, but `aria-hidden` text and collapsed `<details>` bodies are included |
| 10 | Lazy content | scrolling fires `IntersectionObserver` (`LAZY-ITEM-n` appears) |

## Select workaround

Native `<select>` cannot be operated by `click` or `ArrowDown`. Use script:

```js
const s = document.getElementById('sel');
s.value = 'gamma';
s.dispatchEvent(new Event('change', { bubbles: true }));
```

## Re-reading results

After clicking probes, one `eval` collects everything:

```js
return JSON.stringify({
  state: document.getElementById('stateOut').textContent,
  frame: document.getElementById('frameOut').textContent,
  canvas: document.getElementById('canvasOut').textContent,
  store: document.getElementById('storeOut').textContent,
  cors: document.getElementById('corsOut').textContent,
  shadow: document.getElementById('shadowOut').textContent
}, null, 1);
```

Findings are written up in [`../docs/web-viewer-capabilities.md`](../docs/web-viewer-capabilities.md).
