#!/usr/bin/env python3
"""
score_wallpapers.py - Score Wallhaven wallpaper results against Omarchy theme colors.
"""

import sys
import json
import os
from typing import List, Dict, Any, Set, Tuple

# Ensure current directory is in sys.path
script_dir = os.path.dirname(os.path.abspath(__file__))
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

from color_math import score_wallpaper, get_complementary_hex

def parse_args() -> Tuple[str, str, str, Any, Set[str], bool]:
    raw_args = sys.argv[1:]
    
    json_input = None
    colors_str = None
    metric = "delta-e"
    top_n = None
    exclude_ids = set()
    complementary = False

    i = 0
    positional = []
    while i < len(raw_args):
        arg = raw_args[i]
        if arg in ("--metric", "-m") and i + 1 < len(raw_args):
            metric = raw_args[i+1]
            i += 2
        elif arg in ("--top", "-n") and i + 1 < len(raw_args):
            top_n = int(raw_args[i+1])
            i += 2
        elif arg in ("--exclude-ids", "--exclude") and i + 1 < len(raw_args):
            exclude_ids = set(raw_args[i+1].split(","))
            i += 2
        elif arg in ("--colors", "-c") and i + 1 < len(raw_args):
            colors_str = raw_args[i+1]
            i += 2
        elif arg in ("--complementary",):
            complementary = True
            i += 1
        elif arg in ("-h", "--help"):
            print("Usage: score-wallpapers.sh [json_file|-] <theme_colors_comma_separated> [options]")
            print("Options:")
            print("  --metric <delta-e|rgb>   Distance metric (default: delta-e)")
            print("  --top <N>                Limit output to top N results")
            print("  --exclude-ids <id1,id2>  Exclude wallpaper IDs (deduplication)")
            print("  --complementary          Score against complementary colors")
            sys.exit(0)
        else:
            positional.append(arg)
            i += 1

    # Resolve positional arguments
    if len(positional) >= 2:
        json_input = positional[0]
        if not colors_str:
            colors_str = positional[1]
    elif len(positional) == 1:
        # If the argument is an existing file or "-", treat as file
        if os.path.isfile(positional[0]) or positional[0] == "-":
            json_input = positional[0]
        else:
            if not colors_str:
                colors_str = positional[0]
            json_input = "-"

    if not json_input:
        json_input = "-"

    return json_input, colors_str, metric, top_n, exclude_ids, complementary

def load_json(source: str) -> Any:
    try:
        if source == "-":
            return json.load(sys.stdin)
        else:
            with open(source, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception as e:
        sys.stderr.write(f"Error reading JSON input: {e}\n")
        sys.exit(1)

def main():
    json_input, colors_str, metric, top_n, exclude_ids, complementary = parse_args()

    theme_colors = []
    if colors_str:
        for part in colors_str.replace(" ", ",").split(","):
            clean = part.strip()
            if clean:
                if complementary:
                    try:
                        clean = get_complementary_hex(clean)
                    except Exception as e:
                        sys.stderr.write(f"Warning: Failed to compute complementary for {clean}: {e}\n")
                theme_colors.append(clean)

    data_obj = load_json(json_input)

    wallpapers = []
    if isinstance(data_obj, dict):
        if "data" in data_obj and isinstance(data_obj["data"], list):
            wallpapers = data_obj["data"]
        else:
            wallpapers = [data_obj]
    elif isinstance(data_obj, list):
        wallpapers = data_obj
    else:
        sys.stderr.write("Error: Expected JSON array or object with 'data' field\n")
        sys.exit(1)

    scored_items = []
    for item in wallpapers:
        if not isinstance(item, dict):
            continue

        wp_id = str(item.get("id", ""))
        if wp_id and wp_id in exclude_ids:
            continue

        wp_colors = item.get("colors", [])
        score_res = score_wallpaper(wp_colors, theme_colors, metric=metric)

        item_copy = dict(item)
        item_copy["score"] = score_res["score"]
        item_copy["score_details"] = score_res
        scored_items.append(item_copy)

    # Sort ascending by score (lower distance = better match)
    scored_items.sort(key=lambda x: x.get("score", 9999.0))

    if top_n is not None and top_n > 0:
        scored_items = scored_items[:top_n]

    json.dump(scored_items, sys.stdout, indent=2)
    print()

if __name__ == "__main__":
    main()
