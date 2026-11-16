# Search toolbox

Reusable, tested recipes for finding links and images from this device — measured here,
not copied from documentation.

| Path | What it is |
|---|---|
| [`search/`](search/README.md) | DuckDuckGo, Bing, Wikimedia Commons image search |

## Where the findings went

Browser capability notes and the defect register are **not** kept in this repository. They
are filed as agent reports, visible in Downloads → *Pechka agent reports*:

- consolidated capability report (what works on WebView and on the Firefox bridge)
- one advisory per defect, each with a reproduction
- capability gaps (hover, history, drag-and-drop, modifier keys, file picker, PDF)

The test pages and the notes that used to live here are still in git history if they are
needed again.

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

**Do not** rely on Google — it serves a JS-only shell to this browser and returns no result
links at all (verified against its raw HTML).
