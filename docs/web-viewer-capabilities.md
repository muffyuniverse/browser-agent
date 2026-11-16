# Web viewer capabilities — measured

Environment: Android WebView `157.0.8103.38` (Chromium 157), Android 16.
User agent seen by servers:
`Mozilla/5.0 (Linux; Android 16; ...; wv) AppleWebKit/537.36 ... Version/4.0 Chrome/157.0.8103.38 Mobile Safari/537.36`,
plus `X-Requested-With: ai.pechka`.

All claims below were produced by running the tests in [`bench/`](../bench/README.md),
not taken from documentation. Where a feature failed, the failure is recorded with the
observation that produced it.

---

## 1. Sessions and tabs

- Named sessions (`session:"name"`) persist across separate tool calls: navigation,
  scroll position, form state and localStorage all survive between turns.
- `action:"tabs"` lists open webview tabs, e.g.
  `[wv] http://127.0.0.1:37057/ · Web Viewer Capability Bench (webview)`.
- `action:"close"` closes a session.
- **Element refs (`[e1]`, `[e2]`…) expire between turns.** Clicking a stale ref fails with
  `No matching element on page for '[e1]'. Run output:"snapshot" first`. Always re-snapshot
  before acting after a turn boundary.

## 2. Loading pages

- Default `wait` is `done` (load event). Heavy pages (hh.ru, Google) exceed it and return
  `The page did not finish loading before the timeout.` — **even though the page then
  renders fine.**
- `wait:"dom"` is the reliable setting for script-heavy sites.
- `wait_for` with a JS predicate works:
  `action:"wait_for", target:"js:document.getElementById('lazy') !== null"`.

## 3. Reading the page

`output:"snapshot"` returns `## controls` (actionable elements with refs) plus `## content`.

What the controls list includes:

| Element | Exposed? |
|---|---|
| `button`, `link`, `input[text/tel/email/checkbox/radio/range/date/file]` | yes |
| `select` | yes, as `select "Alpha\nBeta\nGamma" value="Alpha"` |
| `textarea`, `summary` | yes |
| **Shadow DOM (open mode)** | **yes** — a button inside `attachShadow({mode:'open'})` appears as a normal control and can be clicked |
| Disabled inputs | yes, marked `[disabled]` |
| iframe contents | **no** — no child controls are listed, and iframe text is absent from `## content` |
| `display:none` text | **no** — excluded from content |
| `aria-hidden="true"` text | **yes** — included in content |
| Collapsed `<details>` body | **yes** — included in content even while closed |

Practical consequence: `## content` is *not* "what a human sees". It leaks `aria-hidden`
text and collapsed accordion bodies, so scraping by text can pick up hidden duplicates.
Cross-check with `eval` + `innerText` when the distinction matters.

## 4. Running JavaScript (`output:"eval"`)

- Requires the page's CSP to allow `'unsafe-eval'`.
  - ✅ local pages served by `serve`, ✅ google.com (`script-src ... 'unsafe-eval'`).
  - ❌ **html.duckduckgo.com** — `script-src blob: https://duckduckgo.com ...`
  - ❌ **bing.com** — `script-src https: 'strict-dynamic' ...` (no `unsafe-eval`)
  - Failure text: `EvalError: Evaluating a string as JavaScript violates the following
    Content Security Policy directive because 'unsafe-eval' is not an allowed source of script`.
- `eval` supports `await`, Promises and top-level `return`.
- Long polls hit `Error: eval timed out waiting for Promise resolution.` (a ~10s loop did).
- `eval` is the only way into **same-origin iframes**: `iframe.contentDocument` works;
  cross-origin frames give a null document (correct browser security, not a viewer bug).

## 5. Interaction

| Action | Result |
|---|---|
| `type` into text/textarea | ✅ value set, real `input` events |
| `type` into a native `<select>` | ✅ **selects by visible label** — reports `Selected "Beta"`, value becomes `beta` |
| `click` button / link / checkbox / radio | ✅ (incl. inside open shadow roots) |
| `click` a native `<select>` | ❌ no option list exposed; clicking changes nothing — use `type` instead |
| `press` `Tab` | ❌ focus did **not** move (`activeElement` unchanged) |
| `press` `Space` on a focused checkbox | ❌ did **not** toggle it |
| `press` `ArrowRight` on a focused range | ❌ value unchanged |
| `press` `Enter` | ⚠️ only where the site's own JS handles `keydown` (hh.ru search submitted); does **not** submit a plain form |
| `scroll` px / `top` / `bottom` | ✅ and it fires `IntersectionObserver` (lazy content loaded: `LAZY-ITEM-1`, `LAZY-ITEM-2`) |

### Root cause: key events are synthetic (`isTrusted === false`)

Instrumented listeners on the target element prove it:

```
keydown(isTrusted=false,key=Space) click(isTrusted=false)
```

- `press` **does** reach page JS: a `keydown` listener receives the key (verified: `[a]`).
- But untrusted events trigger **no browser default action**, so focus traversal (Tab),
  checkbox toggling (Space), range stepping (arrows) and native form submit (Enter) never happen.
- `click` is also `isTrusted=false`, yet it works — per spec, activation behaviour (toggle a
  checkbox, follow a link, press a button) runs for untrusted `click` events too.

**Consequence for real sites:** anything relying on keyboard defaults — Tab navigation,
Space/Enter on controls, arrow-key menus — will not respond. Prefer `click`, `type` and
`eval` for state changes.

### `document.hasFocus()` is false — focus/blur events never fire

```
{"documentHasFocus": false, "visibility": "visible"}
```

`el.focus()` sets `document.activeElement`, but fires **no** `focus` event: a listener
installed by the page never runs (counter stayed 0). Sites that build autocomplete, inline
validation or `focus-visible` styling on `focus`/`blur` will appear not to react.

**Workaround:** use `click` (activation behaviour) or `eval` to set state directly.

**Workaround for setting a `<select>` without a matching label:** set the value and dispatch
a bubbling `change` event:

```js
const s = document.getElementById('sel');
s.value = 'gamma';
s.dispatchEvent(new Event('change', { bubbles: true }));
// verified: value 'gamma', selectedIndex 2
```

## 6. Dialogs, popups, downloads

| Thing | Result |
|---|---|
| `confirm()` | **auto-dismissed** — returns `false`, no hang, page continues |
| `window.open()` | **blocked** — returns null-ish, no new tab appears in `tabs` |
| `<a download>` click | no observable effect; no file appears in the project; not verifiable from here |

## 7. Screenshots and video

- `shot` → viewport PNG.
- `shot {"full":true}` → whole page (176 KB for a 2658px-tall bench).
- `shot {"duration_ms":2200,"fps":8}` → MP4 (32,656 bytes, verified `kind:"video"`).
  `eval` passed alongside runs *before* recording starts.

## 8. Storage and networking from inside a page

- `localStorage` and cookies **persist across reload** (`benchClicks=1`, `benchCookie=1`).
- Form control state resets on reload (normal).
- `fetch()` from page context works, subject to CORS and the network's own limits —
  `https://api.github.com/zen` returned HTTP 403 `API rate limit exceeded for <ip>`,
  which still proves the request left the device and the response was parsed.
- `canvas.toDataURL('image/png')` works (2638-char data URL for a 220×80 canvas).
- `private_addresses` reports `false`, yet `serve` URLs on `127.0.0.1` are fully reachable
  by `browse`, `shot`, `http` and `mcp`.

---

## 9. Search engines — what actually works

| Engine | Verdict | Evidence |
|---|---|---|
| **DuckDuckGo** `html.duckduckgo.com/html/?q=` | ✅ **best** | HTTP 200, no CAPTCHA, `snapshot` yields titles + real URLs |
| **Bing** `www.bing.com/search?q=` | ✅ works | HTTP 200, `snapshot` yields real URLs; consent banner present; `eval` blocked by CSP |
| **Google** `www.google.com/search?q=` | ❌ **unusable** | browser: load timeout, then empty shell; `gbv=1` same; `eval` hangs; raw HTTP 200 (91.6 kB) but **0 matches** for result links in a complete scan |

Google serves a JavaScript-only shell to this WebView. There is no scraping route in.

## 10. Image search

| Source | Verdict |
|---|---|
| **Wikimedia Commons API** | ✅ clean JSON with direct image URLs + thumbnails; downloads verified (red panda 960×640 JPEGs) |
| **Bing Images** | ✅ grid readable via `snapshot` (image-result pages + source domains); raw HTML contains `murl` direct URLs (36 matches) but bulk extraction is awkward without a script runner |
| **Openverse API** | ❌ HTTP 403 — Cloudflare "Just a moment..." challenge |
