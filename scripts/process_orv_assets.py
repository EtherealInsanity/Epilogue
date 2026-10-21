#!/usr/bin/env python3
"""
scripts/process_orv_assets.py
-----------------------------
Automated pipeline to download, color-grade, composite, and refine
ORV-themed visual assets for the Epilogue showcase website.

Outputs:
- docs/assets/images/orv_hero.webp (Unified hero composite: subway + reader + star stream)
- docs/assets/images/icon_reading.png (Thematic reading icon)
- docs/assets/images/icon_studio.png (Thematic studio/editor icon)
- docs/assets/images/icon_themes.png (Thematic customization/star stream icon)
"""

import os
import sys
import subprocess
import urllib.request

RAW_DIR = "/tmp/orv_raw"
OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../docs/assets/images"))

SOURCES = {
    "background_stars": "https://raw.githubusercontent.com/Bittu5134/ORV-Reader/main/website/assets/background-stars.jpg",
    "cover_subway": "https://raw.githubusercontent.com/Bittu5134/ORV-Reader/main/website/assets/images/Cover%20Part%201%20-%20002%20-%20Vol%201%20-%20Episodes%2001-06.jpg",
    "cover_epilogue": "https://raw.githubusercontent.com/Bittu5134/ORV-Reader/main/website/assets/images/Cover%20Part%205%20-%20517%20-%20Vol%202%20-%20Epilogue%201-5.jpg",
    "od_stigma": "https://raw.githubusercontent.com/Bittu5134/ORV-Reader/main/website/assets/od-stigma.webp",
}


def run_cmd(cmd, desc=""):
    print(f"[RUN] {desc or ' '.join(cmd[:3])}")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[ERROR] {res.stderr.strip()}", file=sys.stderr)
        sys.exit(res.returncode)
    return res


def download_sources():
    os.makedirs(RAW_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, url in SOURCES.items():
        ext = os.path.splitext(url)[1].split("?")[0]
        dest = os.path.join(RAW_DIR, f"{name}{ext}")
        if not os.path.exists(dest) or os.path.getsize(dest) == 0:
            print(f"[FETCH] Downloading {name} from {url}...")
            urllib.request.urlretrieve(url, dest)
            print(f"[FETCH] Saved {dest} ({os.path.getsize(dest)} bytes)")
        else:
            print(f"[CACHE] Using cached {dest}")


def build_hero_composite():
    print("\n--- Compositing ORV Hero Artwork ---")
    stars_raw = os.path.join(RAW_DIR, "background_stars.jpg")
    subway_raw = os.path.join(RAW_DIR, "cover_subway.jpg")
    epilogue_raw = os.path.join(RAW_DIR, "cover_epilogue.jpg")
    stigma_raw = os.path.join(RAW_DIR, "od_stigma.webp")
    hero_out = os.path.join(OUT_DIR, "orv_hero.webp")

    # Step 1: Base cosmic nebula (900x580) tinted to Epilogue Midnight (#060d1a)
    stars_prep = os.path.join(RAW_DIR, "step1_stars.png")
    run_cmd([
        "magick", stars_raw,
        "-resize", "900x580^",
        "-gravity", "center",
        "-extent", "900x580",
        "-modulate", "85,120,95",
        "-level", "5%,90%,1.1",
        stars_prep
    ], "Step 1: Process cosmic stars background")

    # Step 2: Subway scene on left (Kim Dokja reading in subway), soft fade to right
    subway_prep = os.path.join(RAW_DIR, "step2_subway.png")
    # Generate horizontal alpha mask for subway (opaque on left, gradient fade to transparent on right)
    subway_mask = os.path.join(RAW_DIR, "mask_subway.png")
    run_cmd([
        "magick", "-size", "900x580", "gradient:#ffffff-#000000",
        "-gamma", "0.7",
        subway_mask
    ], "Generate subway transition mask")

    run_cmd([
        "magick", subway_raw,
        "-resize", "900x580^",
        "-gravity", "west",
        "-extent", "900x580",
        "-modulate", "90,110,105",
        "-level", "10%,90%,1.05",
        subway_mask,
        "-alpha", "Off",
        "-compose", "CopyOpacity",
        "-composite",
        subway_prep
    ], "Step 2: Crop subway and apply horizontal fade mask")

    # Step 3: Epilogue star stream reader on right, blended with screen mode
    epilogue_prep = os.path.join(RAW_DIR, "step3_epilogue.png")
    epilogue_mask = os.path.join(RAW_DIR, "mask_epilogue.png")
    run_cmd([
        "magick", "-size", "900x580", "gradient:#000000-#ffffff",
        "-gamma", "1.4",
        epilogue_mask
    ], "Generate celestial reader mask")

    run_cmd([
        "magick", epilogue_raw,
        "-resize", "900x580^",
        "-gravity", "east",
        "-extent", "900x580",
        "-modulate", "95,125,100",
        epilogue_mask,
        "-alpha", "Off",
        "-compose", "CopyOpacity",
        "-composite",
        epilogue_prep
    ], "Step 3: Crop celestial reader and apply right-side fade mask")

    # Step 4: Stigma / Constellation crest (top right halo)
    stigma_prep = os.path.join(RAW_DIR, "step4_stigma.png")
    run_cmd([
        "magick", stigma_raw,
        "-resize", "240x",
        "-channel", "RGB",
        "-fill", "#64FFDA",
        "-colorize", "60%",
        "+channel",
        stigma_prep
    ], "Step 4: Prepare glowing constellation crest")

    # Step 5: Master Composite + Soft Radial Vignette
    # Create radial vignette mask (transparent edges, solid center)
    vignette_mask = os.path.join(RAW_DIR, "vignette_mask.png")
    run_cmd([
        "magick", "-size", "900x580",
        "radial-gradient:#ffffff-#000000",
        "-level", "20%,90%",
        vignette_mask
    ], "Generate radial vignette falloff mask")

    composite_raw = os.path.join(RAW_DIR, "composite_raw.png")
    run_cmd([
        "magick", stars_prep,
        subway_prep, "-compose", "Over", "-composite",
        epilogue_prep, "-compose", "Screen", "-composite",
        stigma_prep, "-gravity", "northeast", "-geometry", "+35+25", "-compose", "Screen", "-composite",
        composite_raw
    ], "Composite layers together")

    # Step 6: Apply vignette mask and export optimized WebP
    run_cmd([
        "magick", composite_raw,
        vignette_mask,
        "-alpha", "Off",
        "-compose", "CopyOpacity",
        "-composite",
        "-quality", "90",
        "-define", "webp:lossless=false",
        hero_out
    ], f"Step 6: Export polished {hero_out}")

    print(f"[DONE] Created {hero_out} ({os.path.getsize(hero_out)} bytes)")


def build_feature_icons():
    print("\n--- Generating Polished Thematic Feature Icons ---")
    # Icon 1: Reading Engine (Open Book & Pocket Watch motif with cyan glow)
    icon_read = os.path.join(OUT_DIR, "icon_reading.png")
    run_cmd([
        "magick", "-size", "128x128", "xc:none",
        # Glow ring
        "-stroke", "rgba(6, 182, 212, 0.4)", "-strokewidth", "3",
        "-fill", "rgba(10, 25, 47, 0.7)",
        "-draw", "circle 64,64 64,10",
        # Inner pocket watch ring
        "-stroke", "#64FFDA", "-strokewidth", "2.5",
        "-fill", "none",
        "-draw", "circle 64,64 64,22",
        # Clock / Stigma hands
        "-stroke", "#64FFDA", "-strokewidth", "2",
        "-draw", "line 64,64 64,36",
        "-draw", "line 64,64 82,64",
        # Open book pages at bottom
        "-stroke", "#38BDF8", "-strokewidth", "2.5",
        "-draw", "path 'M 36,88 Q 64,74 64,88 Q 64,74 92,88 L 92,98 Q 64,84 64,98 Q 64,84 36,98 Z'",
        "-fill", "rgba(56, 189, 248, 0.25)",
        icon_read
    ], "Generate Reading icon")

    # Icon 2: Studio / Editor (Feather Quill & Manuscript motif)
    icon_studio = os.path.join(OUT_DIR, "icon_studio.png")
    run_cmd([
        "magick", "-size", "128x128", "xc:none",
        # Glow ring
        "-stroke", "rgba(6, 182, 212, 0.4)", "-strokewidth", "3",
        "-fill", "rgba(10, 25, 47, 0.7)",
        "-draw", "circle 64,64 64,10",
        # Manuscript document outline
        "-stroke", "#38BDF8", "-strokewidth", "2",
        "-fill", "rgba(6, 182, 212, 0.15)",
        "-draw", "roundrectangle 36,28 80,100 6,6",
        # Horizontal text lines
        "-stroke", "#64FFDA", "-strokewidth", "2",
        "-draw", "line 46,42 70,42",
        "-draw", "line 46,54 70,54",
        "-draw", "line 46,66 64,66",
        # Feather Quill diagonally across
        "-stroke", "#64FFDA", "-strokewidth", "2.5",
        "-fill", "rgba(100, 255, 218, 0.35)",
        "-draw", "path 'M 94,22 Q 80,48 54,82 L 50,86 L 56,82 Q 78,56 94,22 Z'",
        icon_studio
    ], "Generate Studio icon")

    # Icon 3: Themes / Customization (Constellation Stars & Moon motif)
    icon_themes = os.path.join(OUT_DIR, "icon_themes.png")
    run_cmd([
        "magick", "-size", "128x128", "xc:none",
        # Glow ring
        "-stroke", "rgba(6, 182, 212, 0.4)", "-strokewidth", "3",
        "-fill", "rgba(10, 25, 47, 0.7)",
        "-draw", "circle 64,64 64,10",
        # Crescent Moon
        "-stroke", "#64FFDA", "-strokewidth", "2",
        "-fill", "rgba(100, 255, 218, 0.2)",
        "-draw", "path 'M 64,28 A 36,36 0 1,0 86,92 A 28,28 0 1,1 64,28 Z'",
        # Constellation stars
        "-stroke", "#F59E0B", "-strokewidth", "1.5",
        "-fill", "#F59E0B",
        "-draw", "circle 78,42 78,40",
        "-draw", "circle 92,60 92,58",
        "-draw", "circle 82,78 82,76",
        # Constellation link lines
        "-stroke", "rgba(245, 158, 11, 0.5)", "-strokewidth", "1",
        "-draw", "line 78,42 92,60",
        "-draw", "line 92,60 82,78",
        icon_themes
    ], "Generate Themes icon")

    print(f"[DONE] Created icons in {OUT_DIR}")


if __name__ == "__main__":
    download_sources()
    build_hero_composite()
    build_feature_icons()
    print("\n✅ All ORV visual assets processed and ready for website integration!")
