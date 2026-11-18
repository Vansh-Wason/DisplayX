# Draft row for cleanyourtv's SHOWCASE.md

This goes in the **Forks of the launcher** table. Its four cells are Project | What it is | Built on | By. Fill in the
`<…>` parts once the fork exists. The screenshot link must point at a pinned commit, as the other rows do.

```markdown
| [DisplayX](https://github.com/<you>/<repo>) ([screenshot](https://raw.githubusercontent.com/<you>/<repo>/<commit>/screenshot.jpg), [issues](https://github.com/<you>/<repo>/issues)) | A light, wallpaper-first Google TV-style Home for 2 GB TVs: frosted glass clock that stays readable over any picture, a glass focus that springs between tiles, a wallpaper mode after 5 s idle, Continue watching, and a balanced slideshow. Home measured 43 MB on a 1.8 GB Haier and 63–84 MB on a 2.4 GB TCL (Google TV 14). Own app ID, so it installs beside this launcher. `INTERNET` is used for Continue watching posters (the streaming apps' own image addresses) and an opt-in weather line (open-meteo.com, a place the owner sets); `BIND_ACCESSIBILITY_SERVICE` only where the Home button skips the chosen Home | This repo's launcher (commit 718f98c9) | [@<you>](https://github.com/<you>) |
```

Also add one line under **Find a project by TV brand**, under TCL and Haier, linking the row.

Before opening the PR, read cleanyourtv's `docs/workflows/showcase.md`: its recipe and tests check the row's shape.
