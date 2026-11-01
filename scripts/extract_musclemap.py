#!/usr/bin/env python3
"""Extrait les silhouettes MuscleMap de maquette.html vers un JSON embarqué par PulseDesignSystem.

Usage : python3 -I scripts/extract_musclemap.py maquette.html <sortie.json>
"""
import json
import re
import sys
from html.parser import HTMLParser

SYMBOLS = {"front": "body-front", "back": "body-back"}
FILL = re.compile(r"fill:\s*var\(--mm-([A-Za-z]+)")


class SymbolReader(HTMLParser):
    """Collecte les `d` des tracés d'un symbole, rangés par groupe `fill:var(--mm-<nom>…)`."""

    def __init__(self, symbol_id):
        super().__init__()
        self.symbol_id = symbol_id
        self.view_box = None
        self.body = []
        self.regions = {}
        self._inside = False
        self._groups = []

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "symbol" and attributes.get("id") == self.symbol_id:
            self._inside = True
            self.view_box = [float(v) for v in attributes["viewbox"].split()]
        elif self._inside and tag == "g":
            match = FILL.search(attributes.get("style", ""))
            self._groups.append(match.group(1) if match else None)
        elif self._inside and tag == "path":
            self._add(attributes["d"])

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag == "g" and self._inside:
            self._groups.pop()

    def handle_endtag(self, tag):
        if not self._inside:
            return
        if tag == "g":
            self._groups.pop()
        elif tag == "symbol":
            self._inside = False

    def _add(self, data):
        if not self._groups or self._groups[-1] is None:
            raise SystemExit(f"{self.symbol_id}: tracé hors d'un groupe fill:var(--mm-…)")
        name = self._groups[-1]
        if name == "body":
            self.body.append(data)
        else:
            self.regions.setdefault(name, []).append(data)


def read_license(html):
    match = re.search(r"<!--\s*Silhouettes anatomiques.*?-->", html, re.S)
    if not match:
        raise SystemExit("commentaire de licence introuvable")
    return match.group(0).removeprefix("<!--").removesuffix("-->").strip()


def read_side(html, symbol_id):
    reader = SymbolReader(symbol_id)
    reader.feed(html)
    if reader.view_box is None or not reader.body or not reader.regions:
        raise SystemExit(f"symbole {symbol_id} introuvable ou vide")
    view_box = [int(v) if v == int(v) else v for v in reader.view_box]
    return {"viewBox": view_box, "body": reader.body, "regions": reader.regions}


def main(source, destination):
    with open(source, encoding="utf-8") as handle:
        html = handle.read()
    document = {"license": read_license(html)}
    for side, symbol_id in SYMBOLS.items():
        document[side] = read_side(html, symbol_id)
    with open(destination, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=1)
        handle.write("\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
