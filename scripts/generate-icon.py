#!/usr/bin/env python3
"""Generate CCStatsOSX app icon — full square, macOS applies the mask."""

import subprocess
import os
import math

def generate_svg(size):
    """Two concentric progress rings on dark background. Full square — macOS masks it."""
    cx = size / 2
    cy = size / 2

    # Keep everything well inside the safe zone (Apple recommends ~80% of icon)
    outer_r = size * 0.28
    outer_width = size * 0.055
    inner_r = size * 0.17
    inner_width = size * 0.055

    outer_progress = 0.70
    inner_progress = 0.45

    def arc_path(cx, cy, r, progress):
        start_angle = -90
        end_angle = start_angle + (360 * progress)
        start_rad = math.radians(start_angle)
        end_rad = math.radians(end_angle)
        x1 = cx + r * math.cos(start_rad)
        y1 = cy + r * math.sin(start_rad)
        x2 = cx + r * math.cos(end_rad)
        y2 = cy + r * math.sin(end_rad)
        large_arc = 1 if progress > 0.5 else 0
        return f"M {x1} {y1} A {r} {r} 0 {large_arc} 1 {x2} {y2}"

    outer_arc = arc_path(cx, cy, outer_r, outer_progress)
    inner_arc = arc_path(cx, cy, inner_r, inner_progress)

    outer_end_angle = math.radians(-90 + 360 * outer_progress)
    outer_end_x = cx + outer_r * math.cos(outer_end_angle)
    outer_end_y = cy + outer_r * math.sin(outer_end_angle)

    inner_end_angle = math.radians(-90 + 360 * inner_progress)
    inner_end_x = cx + inner_r * math.cos(inner_end_angle)
    inner_end_y = cy + inner_r * math.sin(inner_end_angle)

    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#2C1810"/>
      <stop offset="100%" stop-color="#1A0E08"/>
    </linearGradient>
    <linearGradient id="outer_grad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#E8845A"/>
      <stop offset="100%" stop-color="#C7613A"/>
    </linearGradient>
    <linearGradient id="inner_grad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#F0A878"/>
      <stop offset="100%" stop-color="#D4845F"/>
    </linearGradient>
  </defs>

  <!-- Full square background — macOS applies squircle mask -->
  <rect width="{size}" height="{size}" fill="url(#bg)"/>

  <!-- Subtle top highlight -->
  <rect width="{size}" height="{size * 0.4}" fill="white" opacity="0.02"/>

  <!-- Track rings (dim) -->
  <circle cx="{cx}" cy="{cy}" r="{outer_r}"
          fill="none" stroke="white" stroke-opacity="0.08"
          stroke-width="{outer_width}" stroke-linecap="round"/>
  <circle cx="{cx}" cy="{cy}" r="{inner_r}"
          fill="none" stroke="white" stroke-opacity="0.08"
          stroke-width="{inner_width}" stroke-linecap="round"/>

  <!-- Outer progress ring (7-day) -->
  <path d="{outer_arc}"
        fill="none" stroke="url(#outer_grad)"
        stroke-width="{outer_width}" stroke-linecap="round"/>

  <!-- End cap glow — outer -->
  <circle cx="{outer_end_x}" cy="{outer_end_y}" r="{outer_width * 0.3}"
          fill="white" opacity="0.5"/>

  <!-- Inner progress ring (5-hour) -->
  <path d="{inner_arc}"
        fill="none" stroke="url(#inner_grad)"
        stroke-width="{inner_width}" stroke-linecap="round"/>

  <!-- End cap glow — inner -->
  <circle cx="{inner_end_x}" cy="{inner_end_y}" r="{inner_width * 0.3}"
          fill="white" opacity="0.5"/>

</svg>'''
    return svg


svg_content = generate_svg(1024)
svg_path = "/tmp/ccstatsosx_icon.svg"
with open(svg_path, "w") as f:
    f.write(svg_content)
print(f"SVG: {svg_path}")

iconset_dir = "/tmp/CCStatsOSX.iconset"
os.makedirs(iconset_dir, exist_ok=True)

try:
    subprocess.run(["which", "rsvg-convert"], check=True, capture_output=True)
    has_rsvg = True
except:
    has_rsvg = False

sizes = {
    "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
}

if has_rsvg:
    for name, sz in sizes.items():
        out = os.path.join(iconset_dir, name)
        subprocess.run(["rsvg-convert", "-w", str(sz), "-h", str(sz), svg_path, "-o", out], check=True)
else:
    large_png = "/tmp/ccstatsosx_large.png"
    subprocess.run(["qlmanage", "-t", "-s", "1024", "-o", "/tmp", svg_path], capture_output=True)
    import glob
    rendered = glob.glob(f"{svg_path}.png")
    if rendered:
        os.rename(rendered[0], large_png)
        for name, sz in sizes.items():
            out = os.path.join(iconset_dir, name)
            subprocess.run(["sips", "-z", str(sz), str(sz), large_png, "--out", out], capture_output=True)

icns_path = "/tmp/CCStatsOSX.icns"
result = subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], capture_output=True, text=True)
if os.path.exists(icns_path):
    print(f"Icon: {icns_path} ({os.path.getsize(icns_path)} bytes)")
else:
    print(f"Error: {result.stderr}")
