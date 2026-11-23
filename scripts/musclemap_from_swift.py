#!/usr/bin/env python3
"""Convertit les silhouettes MuscleMap (fichiers Swift amont) vers le JSON embarqué par PulseDesignSystem.

Usage : python3 -I scripts/musclemap_from_swift.py <dossier Sources/MuscleMap/Data> <musclemap.json>

Lit `{Female,Male}{Front,Back}Paths.swift` (https://github.com/melihcolpan/MuscleMap, commit
d53ddf4d480b65979f1008b203e6b6eda0e67e54) et réécrit le JSON en gardant sa mention de licence.
"""
import json
import os
import re
import sys

# Les régions de `MuscleMapRegion` ; les 13 premières sont en surimpression (`isOverlay`).
OVERLAYS = {
    "frontDeltoid", "hipFlexors", "innerQuad", "lowerAbs", "lowerChest", "lowerTrapezius", "outerQuad",
    "rearDeltoid", "rhomboids", "serratus", "upperAbs", "upperChest", "upperTrapezius",
}
REGIONS = OVERLAYS | {
    "abs", "adductors", "biceps", "calves", "chest", "deltoids", "forearm", "gluteal", "hamstring", "lowerBack",
    "obliques", "quadriceps", "rotatorCuff", "tibialis", "trapezius", "triceps", "upperBack",
}
# Les parties dessinées en couleur de corps.
BODY = {"neck", "head", "hair", "hands", "knees", "ankles", "feet"}

# Les `BodyViewBox` de `BodyPathData.swift` amont : x, y, largeur, hauteur.
VIEW_BOXES = {
    ("female", "front"): [0, 0, 650, 1450],
    ("female", "back"): [823, 0, 650, 1450],
    ("male", "front"): [0, 95, 727, 1280],
    ("male", "back"): [718, 95, 727, 1280],
}

PART = re.compile(r"BodyPartPathData\(\s*slug:\s*\.(\w+)(.*?)\n\s*\)", re.S)
KEYS = ("common", "left", "right")


def read_parts(path):
    """Les calques du fichier, dans son ordre : (nom, tracés `common` puis `left` puis `right`)."""
    with open(path, encoding="utf-8") as handle:
        source = handle.read()
    parts = []
    for match in PART.finditer(source):
        slug, fields = match.groups()
        if slug in REGIONS:
            name = slug
        elif slug in BODY:
            name = "body"
        else:
            raise SystemExit(f"{path}: partie inconnue « {slug} »")
        paths = []
        for key in KEYS:
            array = re.search(rf"\b{key}:\s*\[(.*?)\]", fields, re.S)
            if array:
                paths += re.findall(r'"([^"]+)"', array.group(1))
        if not paths:
            raise SystemExit(f"{path}: « {slug} » sans tracé")
        parts.append({"name": name, "paths": paths})
    if not parts:
        raise SystemExit(f"{path}: aucune partie lue")
    return parts


def read_side(directory, figure, side):
    parts = read_parts(os.path.join(directory, f"{figure.capitalize()}{side.capitalize()}Paths.swift"))
    # Les surimpressions se dessinent par-dessus les régions de base : elles passent en dernier, dans l'ordre du fichier.
    layers = [p for p in parts if p["name"] not in OVERLAYS] + [p for p in parts if p["name"] in OVERLAYS]
    body, regions = [], {}
    for layer in layers:
        if layer["name"] == "body":
            body += layer["paths"]
        else:
            regions.setdefault(layer["name"], []).extend(layer["paths"])
    return {"viewBox": VIEW_BOXES[(figure, side)], "body": body, "regions": regions, "layers": layers}


def main(directory, destination):
    with open(destination, encoding="utf-8") as handle:
        document = {"license": json.load(handle)["license"]}
    for figure in ("female", "male"):
        document[figure] = {side: read_side(directory, figure, side) for side in ("front", "back")}
    with open(destination, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=1)
        handle.write("\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
