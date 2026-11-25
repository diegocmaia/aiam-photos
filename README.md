# aiam.photos

Photographs by aiam, live at https://aiam.pics/

A single static page with no build step: `index.html` plus the `photos/` folder. GitHub Pages publishes `main` within a minute or two of each push.

## Adding a post

```bash
./add-post.sh 2026-12-01 -a "Tram stop in the snow at night" ~/Desktop/IMG_0412.HEIC ~/Desktop/IMG_0413.HEIC
git add -A && git commit -m "Add post" && git push
```

- The first argument is the post date (`YYYY-MM-DD`, or `today`).
- Then list the photos and videos in the order they should appear. More than one file makes a carousel.
- `-a "…"` before a file adds a short description of it for screen readers and search engines. It's optional, and you can also fill it in later in `index.html` (the last value on each line of the `POSTS` list).
- Photos can be JPEG, PNG, HEIC, WebP or TIFF; videos MOV, MP4 or M4V. iPhone photos are straightened automatically.
- The script prints the new post's link, e.g. `…/aiam-photos/#20261201a`.

It needs `cwebp` and `ffmpeg` (`brew install webp ffmpeg`); `sips` is built into macOS.

## Posting to Instagram

```bash
./export-instagram.sh latest          # or a post id, e.g. ./export-instagram.sh 20261201a
```

Writes Instagram-ready files to `~/Desktop/instagram/<id>/`: `1.jpg`, `2.jpg`… in carousel order (1080px wide, centre-cropped only when a photo is taller than 4:5 or wider than 1.91:1), videos copied as `.mp4`, and a `caption.txt` with the post's link and each slide's description to paste into Instagram's alt-text field. Add a `tools/hashtags.txt` to have those appended to the caption automatically. Needs only `sips` and `python3`.

## How the files are organised

| Folder | What's in it |
|---|---|
| `photos/grid/` | `<name>-600.webp` and `<name>-1000.webp`, used in the grid (and as video posters) |
| `photos/large/` | `<name>.webp`, at most 2000px, shown in the viewer |
| `photos/original/` | the original photo as a JPEG, kept for safekeeping (not shown on the site) |
| `photos/video/` | `<name>.mp4` (H.264) |

Each post in `index.html` looks like this:

```js
{ id: "20261201a", date: "2026-12-01", items: [
  ["2026-12-01_20261201a_1", 1440, 1080, 0, "Tram stop in the snow at night", "#4f6a8a"],   // name, width, height, isVideo, description, main colour
]},
```

The main colour (used by the Colour sort and the glow behind photos in the viewer) comes from `tools/colour.py`. Posts are sorted by date on the page, so their order in the file doesn't matter. The post count and date range in the header update on their own.

## Analytics

Cloudflare Web Analytics (cookie-free). The snippet is at the bottom of `index.html`; the dashboard is under Analytics & Logs → Web Analytics at dash.cloudflare.com.
