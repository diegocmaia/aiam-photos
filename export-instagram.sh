#!/bin/bash
# Export a post as Instagram-ready files.
#
# Usage:
#   ./export-instagram.sh <post-id|latest> [output-folder]
#
#   <post-id>  the id from index.html (the part after # in the post's link), or "latest"
#   folder     where to put the files (default: ~/Desktop/instagram/<post-id>)
#
# Writes, in carousel order:
#   1.jpg, 2.jpg, ...   photos at most 1080px wide, in a shape Instagram accepts
#                       (taller than 4:5 is cropped to 4:5, wider than 1.91:1 is cropped to 1.91:1;
#                       anything in between is left alone)
#   3.mp4               videos, copied as they are on the site
#   caption.txt         caption to paste, the post's link, and each slide's description to paste
#                       into Instagram's "Alt text" field (Advanced settings)
#
# If tools/hashtags.txt exists, its contents are added to the end of the caption.
# Needs: sips (built into macOS) and python3.

set -euo pipefail
cd "$(dirname "$0")"

die() { echo "export-instagram: $*" >&2; exit 1; }
command -v sips >/dev/null || die "missing sips (macOS only)"
[ $# -ge 1 ] || { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

id="$1"
out="${2:-$HOME/Desktop/instagram/$id}"

# Pull the post out of index.html: one tab-separated line per file (name, width, height, isVideo, description)
list=$(python3 -I - "$id" <<'PY'
import re, sys
want = sys.argv[1]
src = open("index.html", encoding="utf-8").read()
posts = []
for m in re.finditer(r'\{ id: "([^"]+)", date: "([^"]+)", items: \[\n(.*?)\n  \]\},', src, re.S):
    posts.append((m.group(2), m.group(1), m.group(3)))
if not posts:
    sys.exit("no posts found in index.html")
posts.sort(reverse=True)
if want == "latest":
    post = posts[0]
else:
    post = next((p for p in posts if p[1] == want), None)
    if post is None:
        sys.exit(f"no post with id {want}")
print("#" + post[1])
for line in post[2].splitlines():
    m = re.match(r'\s*\["([^"]+)",\s*(\d+),\s*(\d+),\s*(\d),\s*"((?:[^"\\]|\\.)*)"', line)
    if m:
        name, w, h, vid, alt = m.groups()
        print("\t".join([name, w, h, vid, alt.replace('\\"', '"')]))
PY
) || die "could not read the post"

id=$(echo "$list" | head -1 | sed 's/^#//')
list=$(echo "$list" | tail -n +2)
[ -n "$list" ] || die "post $id has no files"
[ "$1" = latest ] && out="${2:-$HOME/Desktop/instagram/$id}"
mkdir -p "$out"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

caption="$out/caption.txt"
{
  echo "CAPTION (edit, then paste)"
  echo "--------------------------"
  echo
  echo
  echo "Link: https://aiam.pics/#$id"
  echo
  [ -f tools/hashtags.txt ] && { cat tools/hashtags.txt; echo; }
  echo
  echo "ALT TEXT (Advanced settings > Write alt text, one per slide)"
  echo "-----------------------------------------------------------"
} > "$caption"

n=0
while IFS=$'\t' read -r name w h vid alt; do
  n=$((n + 1))
  if [ "$vid" = 1 ]; then
    cp "photos/video/$name.mp4" "$out/$n.mp4"
    echo "  $n.mp4 (video)"
    echo "$n. (video) ${alt:-no description yet}" >> "$caption"
    continue
  fi

  # start from the original, with its phone rotation applied to the pixels
  cp "photos/original/$name.jpg" "$tmp/up.jpg"
  case "$(sips -g orientation "$tmp/up.jpg" | awk '/orientation/{print $2}')" in
    3) sips -r 180 "$tmp/up.jpg" >/dev/null ;;
    6) sips -r 90  "$tmp/up.jpg" >/dev/null ;;
    8) sips -r 270 "$tmp/up.jpg" >/dev/null ;;
  esac
  pw=$(sips -g pixelWidth  "$tmp/up.jpg" | awk '/pixelWidth/{print $2}')
  ph=$(sips -g pixelHeight "$tmp/up.jpg" | awk '/pixelHeight/{print $2}')

  # Instagram accepts shapes from 4:5 (tall) to 1.91:1 (wide). Centre-crop anything outside that.
  cw=$pw; ch=$ph
  if   [ $((ph * 4)) -gt $((pw * 5)) ]; then ch=$((pw * 5 / 4))          # too tall -> 4:5
  elif [ $((pw * 100)) -gt $((ph * 191)) ]; then cw=$((ph * 191 / 100)); fi   # too wide -> 1.91:1
  [ "$cw" = "$pw" ] && [ "$ch" = "$ph" ] || sips -c "$ch" "$cw" "$tmp/up.jpg" >/dev/null

  # 1080px wide is what Instagram shows; never upscale
  [ "$cw" -le 1080 ] || sips --resampleWidth 1080 "$tmp/up.jpg" >/dev/null
  sips -s format jpeg -s formatOptions 92 "$tmp/up.jpg" --out "$out/$n.jpg" >/dev/null
  echo "  $n.jpg (${pw}x${ph} -> $(sips -g pixelWidth "$out/$n.jpg" | awk '/pixelWidth/{print $2}')x$(sips -g pixelHeight "$out/$n.jpg" | awk '/pixelHeight/{print $2}'))"
  echo "$n. ${alt:-no description yet}" >> "$caption"
done <<< "$list"

echo
echo "Exported $n file$([ "$n" -gt 1 ] && echo s) to $out"
echo "Open caption.txt, write your line, then AirDrop the folder to your phone."
