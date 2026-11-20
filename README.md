# aiam.photos

Photographs by aiam, live at https://diegocmaia.github.io/aiam-photos/

A single static page with no build step: `index.html` plus the `photos/` folder.

## Adding a post

1. Put a ~1000px JPEG in `photos/thumb/` and the full-size file in `photos/large/`, using the same name, for example `2026-12-01_myshot_1.jpg`. Videos go in `photos/video/` as `.mp4`, with a poster frame of the same name in `photos/thumb/`.
2. Add an entry at the top of the `POSTS` list in `index.html`:
   ```js
   { id: "myshot", date: "2026-12-01", items: [
     ["2026-12-01_myshot_1", 1000, 750, 0],   // name, width, height, isVideo
   ]},
   ```
3. Commit and push. GitHub Pages republishes within a minute or two.
