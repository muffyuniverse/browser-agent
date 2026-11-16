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
| 1 | Form controls | select / checkbox / radio / range / date / file / disabled inputs are exposed in `snapshot`; checkbox and radio accept `click`; `<select>` is set with `type` (label), not `click` (see below) |
| 2 | Keyboard focus order | whether `press Tab` moves focus — it does not; key events arrive with `isTrusted:false`, so no default action runs |
| 3 | Frames | same-origin iframe readable via `eval`; cross-origin iframe blocked; iframe internals never appear in `snapshot` |
| 4 | Shadow DOM | a button inside `attachShadow({mode:'open'})` is visible to `snapshot` and clickable by the tool (counter reaches 2) |
| 5 | Canvas | `toDataURL('image/png')` works from page context |
| 6 | Storage | `localStorage` and cookies survive a reload |
| 7 | Network in-page | `fetch()` leaves the device and parses the response (GitHub's rate limiter answers 403 for this IP — still a successful round trip) |
| 8 | Downloads & dialogs | `confirm()` is auto-dismissed returning `false` without hanging; `window.open()` is blocked; `<a download>` has no observable effect |
| 9 | Visibility | `display:none` is excluded from `## content`, but `aria-hidden` text and collapsed `<details>` bodies are included |
| 10 | Lazy content | scrolling fires `IntersectionObserver` (`LAZY-ITEM-n` appears) |

## Setting a `<select>`

`click` does not open an option list and `ArrowDown` does not change the value, but
**`type` with the visible option label works**:

```
browse {"session":"wv","action":"type","target":"#sel","text":"Beta"}
→ [action: Selected "Beta"]      value becomes "beta"
```

For a value with no matching label, use script:

```js
const s = document.getElementById('sel');
s.value = 'gamma';
s.dispatchEvent(new Event('change', { bubbles: true }));
```

## Why keyboard defaults fail

`press` delivers untrusted events (`isTrusted:false`). Page `keydown` listeners run, but the
browser performs no default action — so Tab does not move focus and Space does not toggle a
checkbox. `click` is also untrusted yet works, because activation behaviour runs for
untrusted clicks. See [`../docs/web-viewer-capabilities.md`](../docs/web-viewer-capabilities.md) §5.

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

## Pages in this folder

| File | Purpose |
|---|---|
| `index.html` | Main bench — ten sections (forms, frames, shadow DOM, canvas, storage, network, dialogs, visibility, lazy loading) |
| `lab.html` | Second round — contenteditable, input-event trust, file injection, video, postMessage, IndexedDB, service worker, clipboard, geolocation, nested scroll, beforeunload |
| `react.html` | React 18 controlled input (loads React from unpkg) — checks whether `type` updates framework state |
| `console.html` | Emits console messages at every level plus an uncaught exception — verifies the `## console` capture |
| `dialogs.html` | `alert()` / `prompt()` / `confirm()` behaviour |
| `pm-inner.html` | Child frame for the postMessage probe |
| `sw.js` | Service worker that intercepts `/lab-marker.txt` (a file that does not exist) |
| `bye.html` | Destination for the beforeunload navigation test |
| `poke.html` | Third round — adversarial targets: covered button, `pointer-events:none`, disabled, readonly, maxlength, unicode, Backspace, target=_blank, far-below-fold |
| `poke2.html` | Fourth round — interaction gaps: CSS `:hover` menu, closed shadow root, required validation, sandboxed iframe, multi-select, color input, drag and drop |
| `sample.mp4` | Local video source for the `<video>` probe — **git-ignored** (binary), see below |

Results are written up in [`../docs/web-viewer-capabilities.md`](../docs/web-viewer-capabilities.md) §11–§13.

## The video source is not in Git

`sample.mp4` is deliberately ignored (`.gitignore` → `bench/sample.mp4`). Without it the
`<video>` probe reports `error.code 4` (no supported source) instead of a decoded stream —
everything else on `lab.html` still works.

Regenerate it with the viewer itself:

```
shot {"session":"wv","duration_ms":2000,"fps":8,"name":"sample.mp4"}
```

then copy the result to `bench/sample.mp4`:

```
move {"path":"agent/browser/sample.mp4","into":"bench/sample.mp4","copy":true}
```

Any small H.264 MP4 works just as well.
