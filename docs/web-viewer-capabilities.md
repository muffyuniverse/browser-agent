# Web viewer capabilities — measured

Environment: Android WebView `157.0.8103.38` (Chromium 157), Android 16.
User agent seen by servers:
`Mozilla/5.0 (Linux; Android 16; ...; wv) AppleWebKit/537.36 ... Version/4.0 Chrome/157.0.8103.38 Mobile Safari/537.36`,
plus `X-Requested-With: ai.pechka`.

All claims below were produced by running the tests in [`bench/`](../bench/README.md),
not taken from documentation. Where a feature failed, the failure is recorded with the
observation that produced it.

---

## 0. Defect register

Open defects, all filed as advisories with reproductions. **These are expected to be fixed;
the rest of this document is evidence, not a workaround manual.**

| # | Defect | Expected once fixed |
|---|---|---|
| 1 | `press` delivers untrusted key events — Tab/Space/arrows/Enter perform no default action | keyboard defaults work like a real key press |
| 2 | `document.hasFocus()` is false; `focus`/`blur` never fire | pages see normal focus behaviour while driven |
| 3 | `eval` refused by page CSP without `'unsafe-eval'` | eval works on CSP-hardened sites |
| 4 | `type` replaces field content and emits no `keydown`/`beforeinput` | inserts at the caret, emits a normal typing sequence |
| 5 | `click` bypasses hit-testing — overlay, `pointer-events:none`, `display:none` | click obeys what a user could click |
| 6 | `type` writes into `readonly` and ignores `maxlength` | constraints honoured |
| 7 | `target=_blank` / `window.open()` fail silently | tab opens, or an explicit "popup blocked" |
| 8 | `type` on a `<select>` reports success when no option matches | failure listing the real options |
| 9 | **Firefox bridge:** every interaction fails after a tab navigates or reloads — `Interaction script not ready on page` | interactions work on every document load |
| 10 | **Firefox bridge:** `eval` is expression-only (`return` throws an opaque sandbox error), promises are not awaited, page globals are invisible | same contract as WebView; readable errors |

Defects 1–8 were measured on the WebView backend (Android WebView 157); 9–10 on the Firefox
bridge (Firefox Bridge 1.1 v1) after it replaced WebView.

Known limits that are **not** defects (no action exists to test them, or the platform refuses):
PDF rendering, hover-gated UI, history back/forward, drag and drop, modifier-key combos,
closed shadow roots, clipboard and geolocation without user activation.

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
| `click` a native `<select>` | ❌ no option list exposed; clicking changes nothing |
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
Space/Enter on controls, arrow-key menus — do not respond. Defect #1.

### `document.hasFocus()` is false — focus/blur events never fire

```
{"documentHasFocus": false, "visibility": "visible"}
```

`el.focus()` sets `document.activeElement`, but fires **no** `focus` event: a listener
installed by the page never runs (counter stayed 0). Sites that build autocomplete, inline
validation or `focus-visible` styling on `focus`/`blur` will appear not to react.

Focus-dependent UI therefore does not react while the page is driven. Defect #2.

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

---

## 11. Second round — advanced page features

Tested on `bench/lab.html`, `bench/react.html`, `bench/console.html`, `bench/dialogs.html`.

| Feature | Result |
|---|---|
| Contenteditable (`type`) | ✅ text inserted — but it **replaces** existing content, and emits only a synthetic `input` event |
| Events fired by `type` | ⚠️ `input` only (`isTrusted:false`) — **no `keydown`, no `beforeinput`**, so keyup/autocomplete UIs will not fire |
| Existing value on `type` | **replaced, not appended**: `"seed"` + type `"X"` → `"X"` |
| React controlled input | ✅ works — React 18.3.1, `state="hello" changes=1` after `type` |
| File upload | ⚠️ no action opens the native picker; page JS can assign a `File` to `input.files` via `DataTransfer` (verified `injected.txt`, 23 bytes) — missing capability, not a defect |
| `<video>` | ✅ loads and decodes (readyState 4, 720×1280, 2.25 s, no error); `play()` resolves (muted autoplay allowed); `currentTime` advances to 0.38 s |
| `postMessage` | ✅ both directions, parent↔child (`child-ready`, `child-reply`) |
| IndexedDB | ✅ open → put → get round-trip (`{hello:"world", n:42}`) |
| Service worker | ✅ registers, controls the page, intercepts `fetch` (`FROM-SERVICE-WORKER`) — but only once the page is controlled; on first load activation can race the probe |
| Clipboard | ❌ `NotAllowedError` — requires user activation |
| Geolocation | ❌ `error code=1 User denied Geolocation` |
| Nested scroll container | ❌ `scroll` moves only the window; use `el.scrollTop` in script (verified 300) |
| `beforeunload` | ✅ navigation proceeds; browser suppresses the panel (`frame that never had a user gesture`) — cannot trap the session |
| `alert` / `prompt` / `confirm` | all auto-dismissed: alert continues, `prompt` → `null`, `confirm` → `false` |
| Console capture | ✅ a `## console` section appears in browse results with level and `file:line`, including delayed logs and uncaught exceptions |

### Consequences observed

- `type` **replaces** the field rather than inserting at the caret, so an append needs the
  current value read first (defect #4).
- No `keydown`/`keyup` is emitted, so search boxes that suggest on keyup stay quiet even
  though the text lands. Sites listening on `input` (React 18 verified, Vue, most modern
  forms) update normally.
- Console capture is useful independently of the defects: `browse` after an action shows the
  page's own errors.

---

## 12. Third round — adversarial targets (bug hunting)

Tested on `bench/poke.html`. These probe cases where a tool is *likely* to lie about success.

| Case | Result | Verdict |
|---|---|---|
| Button covered by an overlay (`z-index` above it) | click went **through** the overlay, handler ran | ❌ **bug** — hit-testing bypassed |
| Button with `pointer-events:none` | handler ran | ❌ **bug** — same cause |
| `disabled` button | correctly inert, counter stayed 0 | ✅ |
| `readonly` input | value overwritten (`"new"`) | ❌ **bug** — constraint bypassed |
| `maxlength="3"` input | accepted `"abcdefg"` (7 chars) | ❌ **bug** — constraint bypassed |
| `input[type=number]` | ✅ `"42"` | ✅ |
| `input[type=date]` | ✅ `"2026-11-16"` | ✅ |
| Cyrillic + emoji (`Привет 🌍`) | ✅ exact round-trip | ✅ |
| `Backspace` on a filled field | `keydown` delivered (`isTrusted:false`), value unchanged | ❌ same root cause as §5 |
| Link with `target="_blank"` | click handler ran, **no tab opened**, no error | ❌ **bug** — silent failure |
| `window.open()` | blocked, no tab, no error | ❌ same |
| Button far below the fold | scrolled to it and clicked (`scrollY` 2297) | ✅ |
| PDF URL | load times out; session left with **no page** | ❌ limitation — no PDF viewer |
| HTTP 401 (basic auth) | clean `answered HTTP 401`, no hang; tab shows "Webpage not available" | ✅ |

### Cross-session behaviour

- **Cookies are shared across sessions.** A cookie set in session `poke` was readable in a
  separate session `cookie2` on the same origin (`benchCookie=1; xsec=abc123`). Sessions are
  not cookie-isolated.
- **Sessions disappear from `tabs` over time.** Older sessions (`wv`, `lab`, `react`,
  `console`, `dlg`) were gone from the list later in the run while `auth` and `poke`
  remained — idle sessions appear to be evicted, so a long-lived session cannot be assumed
  to survive indefinitely.

### The common thread

Four of the failures above share one cause: **actions are applied to the DOM node rather than
simulated as user input.** A real user cannot click a covered button, cannot type into a
readonly field, and cannot exceed `maxlength`. Because the tool addresses elements directly,
it succeeds where a user would fail — and reports success either way. That mismatch is the
substance of defects #5 and #6.

---

## 13. Fourth round — interaction gaps

Tested on `bench/poke2.html`.

| Case | Result |
|---|---|
| CSS `:hover`-gated menu | ❌ never opens. `click` does not set `:hover`, and synthetic `mouseover`/`mouseenter` do not either (`matches(':hover')` stayed false). No hover action exists. |
| `display:none` element | ❌ `click` **fires its handler** (`menuClicksWhileHidden: 1`) — the strongest form of the occlusion bug |
| Closed shadow root | ❌ invisible to `snapshot` and untargetable by CSS selector; only the component's own exposed function can read its state |
| Sandboxed iframe (`sandbox="allow-scripts"`) | ✅ correctly opaque — `contentDocument` is null |
| Required-field validation | ✅ browser blocks the submit (`validationMessage: "Please fill out this field."`, URL unchanged) — but the tool still reports `Clicked Submit` |
| Valid form submit | ✅ navigates (`/bye.html`) |
| `<select multiple>` by label | ✅ `Selected "Beta"` → `selectedOptions: ["Beta"]` |
| `<input type=color>` | ✅ value set to `#00ff00` |
| Drag and drop | ⚠️ untestable — no drag action exists |
| `wait_for` timeout | ✅ clear error: ``Timed out waiting for `js:...` on page`` |
| `type` on a select with no matching option | ❌ reports `Selected "Nonexistent"` while nothing is selected (`value: ""`, `selectedOptions: []`) |

### Missing actions

`browse` offers read / snapshot / click / type / press / scroll / wait_for / tabs / close.
There is **no** hover, no back/forward history, no drag, no modifier combos (`Ctrl+A`,
`Ctrl+C`), no file picker and no option-list selection. Consequences:

- **Hover-gated UI cannot be exercised at all** — mega-menus, tooltips, and
  reveal-on-hover controls (common on desktop sites) are unreachable.
- **History navigation is unavailable** — after a form submit or a link, there is no way to
  go back except re-navigating to a URL.
- **Text selection and copy cannot be triggered** by keyboard.

### The false-success pattern, five instances

1. click through an overlay
2. click `pointer-events:none`
3. click `display:none`
4. type into `readonly` / beyond `maxlength`
5. select a non-existent option

In every one the tool reported success while the page did something else (or nothing).
These are the cases behind defects #5, #6 and #8: a `0` from `click`/`type` currently means
"dispatched", not "took effect", which is precisely what the fixes need to change.

---

## 14. Firefox bridge — initial survey

`env` now reports `browser  firefox (Firefox Bridge 1.1 v1)`, replacing
`com.google.android.webview 157.0.8103.38`. Measured with Firefox **in the background**.

### Works

- `read`, `snapshot` and `eval` (expression form) on a tab, backgrounded or not.
- Driving an existing `shared` tab.
- Opening new tabs/sessions — each new session loads independently.
- **Interactions on a tab's first document**: `click` toggles a checkbox, `type` sets a
  field and fires a real focus event (`focusLog: k1`), `press` is accepted.
- **`eval` on CSP-strict pages.** DuckDuckGo's `html.duckduckgo.com` returned its title via
  `eval`, so WebView defect #3 does not apply to this backend.
- Fresh tabs report `document.hasFocus(): true` and `visibilityState: "visible"` even with
  Firefox backgrounded, so backgrounding is not what blocks anything.

### Tab model

- Every tab the bridge knows about appears in `tabs`, with my sessions and the person's shared
  tab in the same list.
- **Actions are not limited to the visible tab.** `tabA` was backgrounded (its page reported
  `visibilityState: "hidden"`, `hasFocus: false`) and a `click` still applied — the radio
  moved to "Two" and the earlier checkbox stayed checked. `read`/`snapshot`/`eval` also keep
  working on hidden tabs.
- There is **no activate/switch action**, and none is needed to drive a tab: a session is
  bound to its tab and actions are delivered there regardless of which tab is on screen.
- **The `shared` alias is not stable.** It follows whatever tab the person shares: after a
  re-share, `shared` resolved to a bench tab while the previously shared DuckDuckGo tab was
  only reachable as `tab-10017`. Address a specific tab by the id from `tabs` when it matters.

### The shared tab is not interactive

With exactly one tab open — the person's, unshared and re-shared, everything else closed:

| Check | Result |
|---|---|
| `tabs` | `[shared] https://html.duckduckgo.com/html/ (firefox)` — correct, single tab |
| `read` / `snapshot` / `eval` | work |
| `hasFocus` / `visibility` | `true` / `"visible"` — not a background-tab effect |
| `type` into `input[name=q]` | ❌ `Interaction script not ready on page.` |
| `click` on `input[name=q]` | ❌ same error |
| after the failed click | `document.activeElement` **is** the input — the action half-applies |
| control: a tab opened by the bridge, same moment | `click #chk` works, checkbox checked |

So the bridge distinguishes tabs it opens itself (interactive on the first document) from the
person's shared tab (never interactive). Filed separately from the navigation defect.

### Blocking defect

**After a tab navigates — or simply reloads — every interaction fails** with
`Interaction script not ready on page.` Reproduced four times; `read`/`snapshot`/`eval`
keep working, only the interaction helpers are gone. A new tab to the same URL works until
it navigates. Filed as defect #9.

### Behaviour changes from WebView

| Area | WebView | Firefox bridge |
|---|---|---|
| `eval` form | function body with `return` | **expression only**; `return` throws `@sandbox eval code:1:33` |
| `eval` promises | awaited | **not awaited** — async IIFE times out after 8 s |
| `eval` world | page world (page globals visible) | **isolated** — `typeof window.__videoProbe === "undefined"` |
| `eval` vs CSP | refused (defect #3) | works on DuckDuckGo |
| `wait_for` `js:` timeout message | `Timed out waiting for ... on page` | `... on Firefox tab` (and it fails once the interaction script is gone) |

### Re-tested on fresh tabs (first document, where interaction still works)

| Defect | WebView | Firefox bridge |
|---|---|---|
| #5 click through an overlay | occurs | **occurs** (`clicks: 1`) |
| #5 click `pointer-events:none` | occurs | **occurs** (`clicks: 1`) |
| #6 `readonly` overwritten | occurs | **occurs** (`"new"`) |
| #6 `maxlength` ignored | occurs | **occurs** (`"abcdefg"`) |
| #8 select false success | occurs | **occurs** (`Selected "Nonexistent"`, value `""`) |
| #4 typing emits `keydown` | none | **none** (`keydowns: ""`), value still set |

So #5, #6, #8 and the missing-keydown half of #4 are **tool-layer defects**, not backend
artifacts — they reproduce identically on both. Only #3 (eval vs CSP) turned out to be
WebView-specific.

One difference in the other direction: the **closed** shadow root's contents appeared in the
Firefox text extraction (`Closed shadow button0`), where WebView showed nothing.

### Still not determined

- Tab/focus semantics with Firefox **foregrounded** — the "Tab does not move focus" result is
  confounded by the background state, since focus events are suppressed there.
- Defect #7 (popups / `target=_blank`) on this backend.
