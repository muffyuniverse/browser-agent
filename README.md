# Browser capability notes & toolbox

Measured behaviour of the built-in web viewer, plus reusable search recipes.
Everything here was tested on this device (Android WebView 157 / Chromium 157) — not
copied from documentation.

| Path | What it is |
|---|---|
| [`docs/web-viewer-capabilities.md`](docs/web-viewer-capabilities.md) | What the viewer can and cannot do, with the evidence for each claim |
| [`bench/`](bench/README.md) | A self-hosted page that probes each browser feature; run it to re-verify |
| [`search/`](search/README.md) | Reusable search toolbox: DuckDuckGo, Bing, Wikimedia Commons images |

## Fastest paths

**Search the web for links** (works, no CAPTCHA):

```
browse {"url":"https://html.duckduckgo.com/html/?q=YOUR+QUERY","output":"snapshot"}
```

**Search for images** (returns real image files):

```
http {"request":"@search/commons-images.http"}
```

Then download any `thumburl` from the JSON and show it with `![alt](path)`.

**Do not** rely on Google — it serves a JS-only shell to this WebView and returns no
result links at all (verified against its raw HTML).

## Re-running the capability bench

```
serve {"action":"start","server":"tools","root":"bench"}
browse {"url":"http://127.0.0.1:<port>/","output":"snapshot"}
```

See [`bench/README.md`](bench/README.md) for what each of the ten sections proves.
