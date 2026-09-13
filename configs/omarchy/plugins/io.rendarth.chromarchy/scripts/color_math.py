#!/usr/bin/env python3
"""
color_math.py - Color conversions, distance metrics, and scoring algorithms
for the Chromarchy Omarchy wallpaper plugin.
"""

import math
import colorsys
from typing import List, Tuple, Dict, Any, Optional

def hex_to_rgb(hex_str: str) -> Tuple[int, int, int]:
    """Convert hex string (with or without '#') to (R, G, B) tuple [0..255]."""
    clean = hex_str.strip().lstrip("#")
    if len(clean) == 3:
        clean = "".join([c * 2 for c in clean])
    if len(clean) != 6:
        raise ValueError(f"Invalid hex color: {hex_str}")
    return int(clean[0:2], 16), int(clean[2:4], 16), int(clean[4:6], 16)

def rgb_to_hex(r: int, g: int, b: int) -> str:
    """Convert (R, G, B) tuple to '#rrggbb' hex format."""
    r_clamped = max(0, min(255, int(round(r))))
    g_clamped = max(0, min(255, int(round(g))))
    b_clamped = max(0, min(255, int(round(b))))
    return f"#{r_clamped:02x}{g_clamped:02x}{b_clamped:02x}"

def get_complementary_hex(hex_str: str) -> str:
    """Compute complementary color (rotate hue 180° in HSL space)."""
    r, g, b = hex_to_rgb(hex_str)
    h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
    comp_h = (h + 0.5) % 1.0
    cr, cg, cb = colorsys.hls_to_rgb(comp_h, l, s)
    return rgb_to_hex(int(round(cr * 255)), int(round(cg * 255)), int(round(cb * 255)))

def rgb_to_lab(r: int, g: int, b: int) -> Tuple[float, float, float]:
    """
    Convert sRGB [0..255] to CIE L*a*b* under D65 standard illuminant (2° observer).
    Accurate to standard CIE equations with zero external dependencies.
    """
    def pivot_rgb(c: float) -> float:
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    r_lin = pivot_rgb(r)
    g_lin = pivot_rgb(g)
    b_lin = pivot_rgb(b)

    # Convert linear RGB to XYZ (sRGB D65 matrix)
    x = r_lin * 0.4124564 + g_lin * 0.3575761 + b_lin * 0.1804375
    y = r_lin * 0.2126729 + g_lin * 0.7151522 + b_lin * 0.0721750
    z = r_lin * 0.0193339 + g_lin * 0.1191920 + b_lin * 0.9503041

    # D65 reference white points
    xn, yn, zn = 0.95047, 1.00000, 1.08883

    def pivot_xyz(t: float) -> float:
        return t ** (1.0 / 3.0) if t > 0.008856 else (7.787 * t) + (16.0 / 116.0)

    fx = pivot_xyz(x / xn)
    fy = pivot_xyz(y / yn)
    fz = pivot_xyz(z / zn)

    l_val = (116.0 * fy) - 16.0
    a_val = 500.0 * (fx - fy)
    b_val = 200.0 * (fy - fz)

    return l_val, a_val, b_val

def delta_e_cie76(lab1: Tuple[float, float, float], lab2: Tuple[float, float, float]) -> float:
    """Compute CIE76 Delta-E Euclidean distance in LAB color space."""
    return math.sqrt((lab1[0] - lab2[0])**2 + (lab1[1] - lab2[1])**2 + (lab1[2] - lab2[2])**2)

def euclidean_rgb(rgb1: Tuple[int, int, int], rgb2: Tuple[int, int, int]) -> float:
    """Compute Euclidean distance in 3D RGB color space."""
    return math.sqrt((rgb1[0] - rgb2[0])**2 + (rgb1[1] - rgb2[1])**2 + (rgb1[2] - rgb2[2])**2)

def score_wallpaper(
    wallpaper_palette: List[str],
    theme_colors: List[str],
    metric: str = "delta_e"
) -> Dict[str, Any]:
    """
    Score a wallpaper palette against a list of theme colors.
    Returns dictionary with total score (lower is better), breakdown of matched colors,
    and individual distances.
    """
    if not wallpaper_palette:
        return {"score": 9999.0, "matches": [], "error": "empty palette"}
    if not theme_colors:
        return {"score": 0.0, "matches": []}

    use_delta_e = (metric.lower() in ("delta_e", "delta-e", "cie76", "lab"))

    parsed_wp_rgb = []
    parsed_wp_lab = []
    for c in wallpaper_palette:
        try:
            rgb = hex_to_rgb(c)
            parsed_wp_rgb.append((c, rgb))
            if use_delta_e:
                parsed_wp_lab.append((c, rgb_to_lab(*rgb)))
        except ValueError:
            continue

    if not parsed_wp_rgb:
        return {"score": 9999.0, "matches": [], "error": "no valid wallpaper colors"}

    matches = []
    distances = []

    for tc in theme_colors:
        try:
            tc_rgb = hex_to_rgb(tc)
        except ValueError:
            continue

        best_color = None
        min_dist = float("inf")

        if use_delta_e:
            tc_lab = rgb_to_lab(*tc_rgb)
            for wp_hex, wp_lab in parsed_wp_lab:
                d = delta_e_cie76(tc_lab, wp_lab)
                if d < min_dist:
                    min_dist = d
                    best_color = wp_hex
        else:
            for wp_hex, wp_rgb in parsed_wp_rgb:
                d = euclidean_rgb(tc_rgb, wp_rgb)
                if d < min_dist:
                    min_dist = d
                    best_color = wp_hex

        distances.append(min_dist)
        matches.append({
            "theme_color": tc if tc.startswith("#") else f"#{tc}",
            "matched_color": best_color,
            "distance": round(min_dist, 3)
        })

    if not distances:
        return {"score": 9999.0, "matches": []}

    # Root Mean Square (RMS) scoring:
    # Penalizes outliers so that matching multiple theme colors well
    # ranks higher than matching one perfectly while completely missing another.
    mean_dist = sum(distances) / len(distances)
    rms_dist = math.sqrt(sum(d**2 for d in distances) / len(distances))
    combined_score = round(0.5 * mean_dist + 0.5 * rms_dist, 3)

    return {
        "score": combined_score,
        "mean_distance": round(mean_dist, 3),
        "rms_distance": round(rms_dist, 3),
        "total_distance": round(sum(distances), 3),
        "metric": "delta_e" if use_delta_e else "rgb",
        "matches": matches
    }
