#!/usr/bin/env python3
"""Print the main colour of an image as #rrggbb.

Usage: tools/colour.py <image>   (needs ffmpeg)

Shrinks the image to 24x24 pixels, finds the hue that carries the most colour
(each pixel weighted by how saturated and bright it is), and averages the pixels
of that hue. So a blue sky beats grey pavement, blue-and-orange tiles come out
blue or orange rather than brown, and a nearly colourless photo (a moon in a black
sky) falls back to its plain average: a dark neutral.
"""
import colorsys, subprocess, sys

raw = subprocess.run(
    ["ffmpeg", "-v", "error", "-i", sys.argv[1], "-vf", "scale=24:24", "-frames:v", "1",
     "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
    capture_output=True, check=True).stdout
px = [tuple(raw[i:i + 3]) for i in range(0, len(raw), 3)]
bins = [[] for _ in range(12)]          # 30-degree hue bins
chroma = 0.0
for p in px:
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in p))
    w = s * s * v
    chroma += w
    bins[int(h * 12) % 12].append((p, w))

def mean(pairs):
    tot = sum(w for _, w in pairs) or 1
    return tuple(round(sum(p[k] * w for p, w in pairs) / tot) for k in range(3))

if chroma / len(px) < 0.03:              # nearly colourless: plain average
    rgb = mean([(p, 1) for p in px])
else:
    score = [sum(w for _, w in bins[i - 1] + bins[i] + bins[(i + 1) % 12]) for i in range(12)]
    best = score.index(max(score))
    rgb = mean(bins[best - 1] + bins[best] + bins[(best + 1) % 12])
print("#%02x%02x%02x" % rgb)
