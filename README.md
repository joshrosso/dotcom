# octetz

The octetz.com website.

Run site:

```
hugo server --minify \
    --theme book \
    # ensures links and reference like rss have correct host \
    --baseUrl=https://octetz.com \
    # ensures links and reference like rss have correct port \
    --appendPort=false
```