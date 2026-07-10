import json
import sys

path = r"C:\godot\xiuxian\data\exportjson\didian_locations.json"

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

def simplify_materials(materials_str):
    if not materials_str or materials_str == "null":
        return None
    materials = json.loads(materials_str)
    parts = []
    for m in materials:
        parts.append(f"{m['id']}:{m['drop_pool']}")
    return "|".join(parts)

def simplify_drop_pools(drop_pools_str):
    if not drop_pools_str or drop_pools_str == "{}":
        return {}
    drop_pools = json.loads(drop_pools_str)
    out = {}
    for pool_name, pool in drop_pools.items():
        entries = pool.get("entries", [])
        parts = []
        for entry in entries:
            variants = entry.get("variants", [])
            if variants:
                for variant in variants:
                    v_id = variant.get("id", "")
                    v_weight = variant.get("weight", 1)
                    parts.append(f"{v_id}:{v_weight}")
            else:
                e_id = entry.get("id", "")
                e_weight = entry.get("weight", 1)
                parts.append(f"{e_id}:{e_weight}")
        out[pool_name] = "|".join(parts)
    return out

def simplify_event_pool(event_pool):
    if not event_pool:
        return ""
    parts = []
    for event_id in event_pool:
        parts.append(f"{event_id}:1")
    return "|".join(parts)

for location_id, location in data.items():
    if location.get("materials") and location["materials"] != "null":
        location["materials"] = simplify_materials(location["materials"])
    if location.get("drop_pools") and location["drop_pools"] != "{}":
        location["drop_pools"] = simplify_drop_pools(location["drop_pools"])
    if location.get("event_pool"):
        location["event_pool"] = simplify_event_pool(location["event_pool"])

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

print("Simplified didian_locations.json")
