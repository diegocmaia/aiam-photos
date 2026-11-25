#!/bin/bash
# Add a new post to the site.
#
# Usage:
#   ./add-post.sh <date> [-a "description"] <file> [[-a "description"] <file> ...]
#
#   <date>   YYYY-MM-DD, or "today"
#   <file>   photos (.jpg .jpeg .png .heic .webp .tif) or videos (.mov .mp4 .m4v), in the order
#            they should appear in the post. Several files make a carousel.
#   -a TEXT  optional description of the next file, read aloud by screen readers.
#
# Example:
#   ./add-post.sh 2026-12-01 -a "Tram stop in the snow at night" ~/Desktop/IMG_0412.HEIC ~/Desktop/IMG_0413.HEIC
#
# It writes the web-sized copies into photos/ and adds the post to index.html.
# Then review with `git status`, and commit and push to publish.
# Needs: sips (built into macOS), cwebp and ffmpeg (brew install webp ffmpeg).

set -euo pipefail
cd "$(dirname "$0")"

die() { echo "add-post: $*" >&2; exit 1; }
for tool in sips cwebp ffmpeg ffprobe python3; do
  command -v "$tool" >/dev/null || die "missing $tool (try: brew install webp ffmpeg)"
done

[ $# -ge 2 ] || { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

date="$1"; shift
[ "$date" = today ] && date=$(date +%F)
[[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "date must look like 2026-12-01 (got '$date')"

# Post id: the date plus a letter, unique within index.html (e.g. 20261201a). It is also the post's #link.
base=${date//-/}
for l in {a..z}; do
  grep -q "id: \"$base$l\"" index.html || { id="$base$l"; break; }
done
[ -n "${id:-}" ] || die "too many posts on $date"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p photos/original photos/large photos/grid photos/video
entries="$tmp/entries.json"; : > "$entries"

# grid copies: 600 and 1000px wide (never upscaled)
make_grid() { # <upright jpeg> <name>
  local src="$1" name="$2" w
  w=$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')
  for size in 600 1000; do
    local target=$(( w < size ? w : size ))
    cwebp -quiet -q 78 -resize "$target" 0 "$src" -o "photos/grid/$name-$size.webp"
  done
}

n=0; alt=""
while [ $# -gt 0 ]; do
  if [ "$1" = "-a" ]; then [ $# -ge 2 ] || die "-a needs a description"; alt="$2"; shift 2; continue; fi
  file="$1"; shift
  [ -f "$file" ] || die "no such file: $file"
  n=$((n + 1)); name="${date}_${id}_$n"
  ext=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')

  case "$ext" in
    jpg|jpeg|png|heic|heif|webp|tif|tiff)
      # keep the original as a JPEG for safekeeping
      if [ "$ext" = jpg ] || [ "$ext" = jpeg ]; then cp "$file" "photos/original/$name.jpg"
      else sips -s format jpeg -s formatOptions 92 "$file" --out "photos/original/$name.jpg" >/dev/null; fi
      # straighten phone photos: apply the EXIF rotation to the pixels before encoding
      cp "photos/original/$name.jpg" "$tmp/up.jpg"
      case "$(sips -g orientation "$tmp/up.jpg" | awk '/orientation/{print $2}')" in
        3) sips -r 180 "$tmp/up.jpg" >/dev/null ;;
        6) sips -r 90  "$tmp/up.jpg" >/dev/null ;;
        8) sips -r 270 "$tmp/up.jpg" >/dev/null ;;
      esac
      w=$(sips -g pixelWidth "$tmp/up.jpg" | awk '/pixelWidth/{print $2}')
      h=$(sips -g pixelHeight "$tmp/up.jpg" | awk '/pixelHeight/{print $2}')
      # viewer copy: longest side at most 2000px
      if   [ "$w" -gt 2000 ] && [ "$w" -ge "$h" ]; then cwebp -quiet -q 82 -resize 2000 0 "$tmp/up.jpg" -o "photos/large/$name.webp"
      elif [ "$h" -gt 2000 ]; then cwebp -quiet -q 82 -resize 0 2000 "$tmp/up.jpg" -o "photos/large/$name.webp"
      else cwebp -quiet -q 82 "$tmp/up.jpg" -o "photos/large/$name.webp"; fi
      make_grid "$tmp/up.jpg" "$name"
      video=0
      ;;
    mov|mp4|m4v)
      # H.264 MP4 that plays everywhere, at most 1280px wide, with fast start for streaming
      ffmpeg -v error -y -i "$file" -vf "scale='min(1280,iw)':-2" -c:v libx264 -crf 23 -preset medium \
        -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart "photos/video/$name.mp4"
      ffmpeg -v error -y -ss 0.3 -i "photos/video/$name.mp4" -frames:v 1 -q:v 2 "$tmp/poster.jpg"
      make_grid "$tmp/poster.jpg" "$name"
      IFS=, read -r w h < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "photos/video/$name.mp4")
      video=1
      ;;
    *) die "unsupported file type: $file" ;;
  esac

  colour=$(python3 -I tools/colour.py "photos/grid/$name-600.webp")   # for the colour sort and the viewer glow
  python3 -I -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "$name" "$w" "$h" "$video" "$alt" "$colour" >> "$entries"
  echo "  added $name (${w}x${h}${alt:+, \"$alt\"})"
  alt=""
done
[ "$n" -gt 0 ] || die "no files given"

# insert the post at the top of the POSTS list in index.html
python3 -I - "$id" "$date" "$entries" <<'PY'
import json, sys
post_id, date, entries = sys.argv[1], sys.argv[2], sys.argv[3]
items = []
for line in open(entries):
    name, w, h, video, alt, colour = json.loads(line)
    items.append(f'    [{json.dumps(name)}, {int(w)},{int(h)}, {int(video)}, {json.dumps(alt, ensure_ascii=False)}, {json.dumps(colour)}],')
block = f'  {{ id: {json.dumps(post_id)}, date: {json.dumps(date)}, items: [\n' + "\n".join(items) + "\n  ]},\n"
src = open("index.html", encoding="utf-8").read()
anchor = "const POSTS = [\n"
assert src.count(anchor) == 1, "could not find the POSTS list in index.html"
open("index.html", "w", encoding="utf-8").write(src.replace(anchor, anchor + block, 1))
PY

echo
echo "Post $id ($n file$([ "$n" -gt 1 ] && echo s)) added. Its link: https://aiam.pics/#$id"
echo "Next: check it with 'git status', then:  git add -A && git commit -m \"Add post $id\" && git push"
