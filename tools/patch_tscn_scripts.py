#!/usr/bin/env python3
"""Add press_scale_feedback to Button/TextureButton nodes and long_press_scroll_container to ScrollContainer nodes."""

from __future__ import annotations

import glob
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESS_PATH = "res://scripts/ui/press_scale_feedback.gd"
LPSC_PATH = "res://scripts/ui/components/long_press_scroll_container.gd"
PRESS_UID = 'uid="uid://cwd4djdi6atf6"'
PRESS_CHILD_NAME = "PressScaleFeedback"
PRESS_TARGET_TYPES = frozenset({"Button", "TextureButton"})

NODE_HEADER_RE = re.compile(
    r'^\[node name="(?P<name>[^"]+)" type="(?P<type>[^"]+)"(?P<attrs>[^\]]*)\]\n',
    re.MULTILINE,
)
EXT_RESOURCE_RE = re.compile(
    r'^\[ext_resource type="Script"(?: uid="[^"]+")? path="([^"]+)" id="([^"]+)"\]\n',
    re.MULTILINE,
)
LOAD_STEPS_RE = re.compile(r"^\[gd_scene load_steps=(\d+)", re.MULTILINE)
SCRIPT_LINE_RE = re.compile(r'^script = ExtResource\("([^"]+)"\)\n', re.MULTILINE)


def parse_nodes(content: str) -> list[dict]:
    nodes: list[dict] = []
    for match in NODE_HEADER_RE.finditer(content):
        parent = ""
        parent_match = re.search(r' parent="([^"]+)"', match.group("attrs"))
        if parent_match:
            parent = parent_match.group(1)
        start = match.end()
        next_node = NODE_HEADER_RE.search(content, start)
        end = next_node.start() if next_node else len(content)
        body = content[start:end]
        path = f"{parent}/{match.group('name')}" if parent else match.group("name")
        nodes.append(
            {
                "name": match.group("name"),
                "type": match.group("type"),
                "attrs": match.group("attrs"),
                "header": match.group(0),
                "body": body,
                "path": path,
                "header_start": match.start(),
                "body_start": start,
                "end": end,
            }
        )
    return nodes


def next_ext_id(content: str) -> str:
    ids = [int(m.group(1)) for m in re.finditer(r'id="(\d+)_', content)]
    return f"{max(ids, default=0) + 1}_auto"


def find_ext_id(content: str, script_path: str) -> str | None:
    for m in EXT_RESOURCE_RE.finditer(content):
        if m.group(1) == script_path:
            return m.group(2)
    return None


def ensure_ext_resource(content: str, script_path: str, prefer_uid: str | None = None) -> tuple[str, str]:
    existing = find_ext_id(content, script_path)
    if existing:
        return content, existing

    ext_id = next_ext_id(content)
    uid_part = f" {prefer_uid}" if prefer_uid else ""
    ext_line = f'[ext_resource type="Script"{uid_part} path="{script_path}" id="{ext_id}"]\n'

    node_idx = content.find("\n[node ")
    sub_idx = content.find("\n[sub_resource")
    candidates = [i for i in (node_idx, sub_idx) if i != -1]
    insert_at = min(candidates) if candidates else len(content)

    content = content[:insert_at] + "\n" + ext_line + content[insert_at:]

    def bump_load_steps(match: re.Match[str]) -> str:
        return f"[gd_scene load_steps={int(match.group(1)) + 1}"

    if LOAD_STEPS_RE.search(content):
        content = LOAD_STEPS_RE.sub(bump_load_steps, content, count=1)

    return content, ext_id


def script_path_for_ext(content: str, ext_id: str) -> str | None:
    for m in EXT_RESOURCE_RE.finditer(content):
        if m.group(2) == ext_id:
            return m.group(1)
    return None


def node_has_press_feedback(content: str, nodes: list[dict], button: dict) -> bool:
    prefix = button["path"] + "/"
    for node in nodes:
        if not node["path"].startswith(prefix):
            continue
        if node["type"] != "Node":
            continue
        m = SCRIPT_LINE_RE.search(node["body"])
        if m and script_path_for_ext(content, m.group(1)) == PRESS_PATH:
            return True
    m = SCRIPT_LINE_RE.search(button["body"])
    if m and script_path_for_ext(content, m.group(1)) == PRESS_PATH:
        return True
    return False


def insert_script_line(body: str, ext_id: str) -> str:
    lines = body.split("\n")
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith("unique_name_in_owner"):
            insert_idx = i + 1
            continue
        if line:
            insert_idx = i
            break
    lines.insert(insert_idx, f'script = ExtResource("{ext_id}")')
    return "\n".join(lines) + ("\n" if body.endswith("\n") else "")


def make_press_child_block(parent_path: str, ext_id: str) -> str:
    return (
        f'\n[node name="{PRESS_CHILD_NAME}" type="Node" parent="{parent_path}"]\n'
        f'script = ExtResource("{ext_id}")\n\n'
    )


def patch_file(path: Path, dry_run: bool = False) -> dict:
    content = path.read_text(encoding="utf-8")
    original = content
    stats = {"buttons": 0, "texture_buttons": 0, "scrolls": 0}

    nodes = parse_nodes(content)
    press_targets = [n for n in nodes if n["type"] in PRESS_TARGET_TYPES]
    scrolls = [n for n in nodes if n["type"] == "ScrollContainer"]

    needs_press = [b for b in press_targets if not node_has_press_feedback(content, nodes, b)]
    needs_scroll = []
    for sc in scrolls:
        m = SCRIPT_LINE_RE.search(sc["body"])
        if m and script_path_for_ext(content, m.group(1)) == LPSC_PATH:
            continue
        if m:
            print(f"  SKIP {path}: {sc['path']} (ScrollContainer) already has another script")
            continue
        needs_scroll.append(sc)

    if not needs_press and not needs_scroll:
        return stats

    if needs_press:
        content, press_ext_id = ensure_ext_resource(content, PRESS_PATH, PRESS_UID)
    else:
        press_ext_id = find_ext_id(content, PRESS_PATH) or ""

    if needs_scroll:
        content, lpsc_ext_id = ensure_ext_resource(content, LPSC_PATH)
    else:
        lpsc_ext_id = find_ext_id(content, LPSC_PATH) or ""

    nodes = parse_nodes(content)
    replacements: list[tuple[int, int, str]] = []
    insertions: list[tuple[int, str]] = []

    for button in needs_press:
        node = next(n for n in nodes if n["path"] == button["path"])
        stat_key = "texture_buttons" if node["type"] == "TextureButton" else "buttons"
        m = SCRIPT_LINE_RE.search(node["body"])
        if m and script_path_for_ext(content, m.group(1)) != PRESS_PATH:
            insertions.append((node["end"], make_press_child_block(node["path"], press_ext_id)))
            stats[stat_key] += 1
            continue

        new_body = insert_script_line(node["body"], press_ext_id)
        replacements.append((node["body_start"], node["end"], new_body))
        stats[stat_key] += 1

    for sc in needs_scroll:
        node = next(n for n in nodes if n["path"] == sc["path"])
        new_body = insert_script_line(node["body"], lpsc_ext_id)
        replacements.append((node["body_start"], node["end"], new_body))
        stats["scrolls"] += 1

    for start, end, new_text in sorted(replacements, key=lambda item: item[0], reverse=True):
        content = content[:start] + new_text + content[end:]

    for offset, block in sorted(insertions, key=lambda item: item[0], reverse=True):
        content = content[:offset] + block + content[offset:]

    if content != original and not dry_run:
        path.write_text(content, encoding="utf-8", newline="\n")

    return stats


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    total = {"buttons": 0, "texture_buttons": 0, "scrolls": 0, "files": 0}

    for path_str in sorted(glob.glob(str(ROOT / "scenes/**/*.tscn"), recursive=True)):
        path = Path(path_str)
        stats = patch_file(path, dry_run=dry_run)
        if stats["buttons"] or stats["texture_buttons"] or stats["scrolls"]:
            total["files"] += 1
            total["buttons"] += stats["buttons"]
            total["texture_buttons"] += stats["texture_buttons"]
            total["scrolls"] += stats["scrolls"]
            rel = path.relative_to(ROOT)
            print(
                f"{rel}: +{stats['buttons']} buttons, "
                f"+{stats['texture_buttons']} texture_buttons, +{stats['scrolls']} scrolls"
            )

    print(
        f"Done ({'dry-run' if dry_run else 'applied'}): "
        f"{total['files']} files, {total['buttons']} buttons, "
        f"{total['texture_buttons']} texture_buttons, {total['scrolls']} scroll containers"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
