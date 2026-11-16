# Search toolbox

Reusable, tested recipes. Google is deliberately absent — it returns a JS-only shell with no
result links at all (verified against its raw HTML).

---

## 1. Web search for links — DuckDuckGo (recommended)

**Best method** — let the accessibility tree do the parsing:

```
browse {"url":"https://html.duckduckgo.com/html/?q=android+webview+automation","output":"snapshot"}
```

Each result comes back as `[eN] link "Title" -> //duckduckgo.com/l/?uddg=<urlencoded target>`.
Decode `uddg=` to get the real URL. Titles and snippets are in `## content`.

**Raw HTML method** — when you want to post-process:

```
http {"request":"@search/ddg-search.http","name":"ddg.html"}
list {"path":"agent/http/ddg\\.html$","grep":"result__a"}
```

Edit the `q=` value in the `.http` file before calling. URL-encode the query: spaces → `+`.

## 2. Web search — Bing

```
browse {"url":"https://www.bing.com/search?q=YOUR+QUERY&setlang=en","output":"snapshot"}
```

Real URLs come back directly (`[eN] link "Title" -> https://...`). Expect a cookie/consent
banner (`Privacy Statement` / `Accept` / `Reject`) in the controls list.

- `eval` on bing.com depends on the browser backend: refused under WebView (CSP), works
  under the Firefox bridge. `snapshot` works either way.
- Add `&setlang=en` to keep the UI in English regardless of IP geolocation.

## 3. Image search — Wikimedia Commons (recommended, returns real files)

```
http {"request":"@search/commons-images.http","name":"commons.json"}
read {"path":"agent/http/commons.json"}
```

The response is JSON; each page has
`imageinfo[0].thumburl` (800px thumbnail) and `imageinfo[0].url` (original).
Download a thumbnail and display it:

```
http {"request":"GET <thumburl>\nUser-Agent: PechkaBrowserTest/1.0\n\n","name":"pic.jpg"}
```

then `![what it is](agent/http/pic.jpg)`.

Edit `gsrsearch=` in the file to change the query. `filetype:bitmap` keeps it to photos;
drop it to include SVG/diagrams. `gsrlimit` max 50 (API), `gsrnamespace=6` = File namespace.

## 4. Image search — Bing Images (grid, not files)

```
browse {"url":"https://www.bing.com/images/search?q=red+panda&setlang=en","output":"snapshot"}
```

Gives image-result detail links plus publisher domains (e.g. `nathab.com`) — good for
"who published this photo", not for grabbing the file. Direct URLs live in the raw HTML as
`"murl":"https://..."` (`http` + `list {"grep":"murl"}` finds them, ~36 per page), but
pulling many out at once needs a real script runner, which this environment lacks.

---

## Rules of thumb

- **Decode before trusting**: DDG wraps links in `uddg=`; Bing sometimes wraps in its own
  redirect. Always check the final host.
- **Snapshot vs eval**: some third-party sites refuse `eval` via CSP, depending on the
  backend; `snapshot` is unaffected because it does not inject JavaScript.
- **Re-snapshot each turn**: `[eN]` refs die at turn boundaries.
- **Heavy pages**: if a load times out, retry with `wait:"dom"` before concluding it's blocked.
- **Rate limits are real**: an in-page `fetch` to api.github.com returned HTTP 403
  `API rate limit exceeded` — that is the network refusing the device's IP, not a viewer bug.
