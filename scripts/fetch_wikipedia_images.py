#!/usr/bin/env python3
"""Give the built-in plants (ids 900001+) real photos from Wikipedia /
Wikimedia Commons instead of the flat SVG icons.

For each built-in plant it looks up Wikipedia articles (scientific name,
common name, species, genus, in an order that suits the plant), takes the
article's lead image, checks on Commons that the file is public domain or
Creative Commons (CC0 / CC BY / CC BY-SA), downloads a ~330px-wide JPEG
thumbnail into the frontend's public/images/plants/<id>.jpg and points the
snapshot JSON at it, recording an image_credit for the details page.

Usage (from the backend repo root):
    python3 scripts/fetch_wikipedia_images.py ../backyarder-ui [--dry-run]

Every API response is cached in scripts/.wikipedia_cache.json (gitignored), so
reruns cost no requests apart from images that are not downloaded yet.
Plants with no acceptable image keep their SVG. OVERRIDES pins or blocks the
picture for plants where the automatic choice was wrong.
"""
import glob
import html
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

DETAILS_DIR = "mock_json/details"
INDEX = "mock_json/index.json"
CACHE = os.path.join(os.path.dirname(__file__), ".wikipedia_cache.json")
USER_AGENT = "Backyarder/1.0 (https://github.com/Backyarder; plant photo snapshot script)"
WIDTH = 330  # a standard Wikimedia thumbnail step
FIRST_BUILT_IN = 900001

# Wikipedia titles to use instead of the automatic candidates (tried in
# order), or None for "no photo, keep the SVG". Filled in after eyeballing.
OVERRIDES = {
    900356: ["Maize", "Zea mays"],  # popcorn: the Popcorn article shows popped corn
    900419: ["Hippeastrum"],         # amaryllis: the Amaryllis article is Amaryllis belladonna
}

# Commons files never to use (wrong subject, food shots, maps...).
BAD_FILES = {
    "Pomegranate_Juice_(2019).jpg",          # juice, not the plant
    "Pastinaca_sativa_MHNT.BOT.2004.0.jpg",  # parsnip seeds
    "Pseudotsuga_menziesii_4584.JPG",        # a coastline more than a tree
    "Calibrachoa_×hybrida_sl7.jpg",          # barely shows the flowers
    # Drawings the file-name pattern below misses:
    "Allium_sativum_Woodwill_1793.jpg", "Ficus_carica_L,_1771.jpg", "Hypericum_aureum_139-8498_edit.png", "Hypericum_aureum_139-8498.jpg",
    "Pimpinella_anisum_BYN.jpg", "Pimpinella_anisum_Mann.jpg", "Begonia_rex.jpg",
}

FREE = re.compile(r"^(cc0|cc[ -]by(-sa)?( |-|$)|public domain|pd\b|pd-)", re.I)


class Wiki:
    def __init__(self):
        self.cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
        self.last = 0.0
        self.calls = 0

    def get(self, url):
        if url in self.cache:
            return self.cache[url]
        wait = 1.0 - (time.time() - self.last)
        if wait > 0:
            time.sleep(wait)
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = json.load(r)
        self.last = time.time()
        self.calls += 1
        self.cache[url] = data
        if self.calls % 10 == 0:
            self.save()
        return data

    def save(self):
        with open(CACHE, "w") as f:
            json.dump(self.cache, f)

    def pages(self, titles):
        """title -> {title, image, extract, disambiguation} (None when missing)."""
        out = {}
        titles = sorted(set(titles))
        for i in range(0, len(titles), 20):
            chunk = titles[i:i + 20]
            q = urllib.parse.urlencode({
                "action": "query", "format": "json", "formatversion": 2, "redirects": 1,
                "prop": "pageimages|pageprops|extracts", "piprop": "name", "pilicense": "free",
                "ppprop": "disambiguation|wikibase_item", "exintro": 1, "explaintext": 1, "exsentences": 3,
                "exlimit": "max", "titles": "|".join(chunk),
            })
            data = self.get(f"https://en.wikipedia.org/w/api.php?{q}")["query"]
            hops = {n["from"]: n["to"] for n in data.get("normalized", [])}
            hops.update({r["from"]: r["to"] for r in data.get("redirects", [])})
            by_title = {p["title"]: p for p in data.get("pages", [])}
            for t in chunk:
                final, seen = t, set()
                while final in hops and final not in seen:
                    seen.add(final)
                    final = hops[final]
                p = by_title.get(final)
                if not p or p.get("missing") or p.get("invalid"):
                    out[t] = None
                    continue
                out[t] = {
                    "title": p["title"],
                    "image": p.get("pageimage"),
                    "extract": p.get("extract", ""),
                    "disambiguation": "disambiguation" in p.get("pageprops", {}),
                    "item": p.get("pageprops", {}).get("wikibase_item"),
                }
        return out

    def wikidata_images(self, items):
        """Wikidata item -> its P18 (image) file name, a second choice when the
        article's lead image is unusable."""
        out = {}
        items = sorted(set(i for i in items if i))
        for i in range(0, len(items), 150):
            chunk = items[i:i + 150]
            sparql = ("SELECT ?item ?img WHERE { VALUES ?item { %s } ?item wdt:P18 ?img }"
                      % " ".join("wd:" + q for q in chunk))
            q = urllib.parse.urlencode({"query": sparql, "format": "json"})
            data = self.get(f"https://query.wikidata.org/sparql?{q}")
            for row in data["results"]["bindings"]:
                qid = row["item"]["value"].rsplit("/", 1)[-1]
                name = urllib.parse.unquote(row["img"]["value"].rsplit("/", 1)[-1]).replace(" ", "_")
                out.setdefault(qid, name)
        return out

    def files(self, names):
        """file name -> Commons imageinfo (url, thumb, mime, license, artist) or None."""
        out = {}
        names = sorted(set(names))
        for i in range(0, len(names), 40):
            chunk = names[i:i + 40]
            q = urllib.parse.urlencode({
                "action": "query", "format": "json", "formatversion": 2, "prop": "imageinfo",
                "iiprop": "url|mime|size|extmetadata", "iiurlwidth": WIDTH,
                "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist|Credit|ObjectName",
                "titles": "|".join("File:" + n for n in chunk),
            })
            data = self.get(f"https://commons.wikimedia.org/w/api.php?{q}")["query"]
            hops = {n["from"]: n["to"] for n in data.get("normalized", [])}
            by_title = {p["title"]: p for p in data.get("pages", [])}
            for n in chunk:
                t = "File:" + n
                p = by_title.get(hops.get(t, t))
                info = (p or {}).get("imageinfo")
                if not info:
                    out[n] = None  # not on Commons (en.wikipedia-local files are often non-free)
                    continue
                out[n] = file_info(info[0])
        return out

    def search(self, text):
        """Top Commons photos for a search, as [(file name, info)]: the last
        resort when no article has a usable photo."""
        q = urllib.parse.urlencode({
            "action": "query", "format": "json", "formatversion": 2, "generator": "search",
            "gsrsearch": f"{text} filetype:bitmap", "gsrnamespace": 6, "gsrlimit": 8,
            "prop": "imageinfo", "iiprop": "url|mime|size|extmetadata", "iiurlwidth": WIDTH,
            "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist",
        })
        data = self.get(f"https://commons.wikimedia.org/w/api.php?{q}").get("query", {})
        pages = sorted(data.get("pages", []), key=lambda p: p.get("index", 0))
        return [(p["title"][5:].replace(" ", "_"), file_info(p["imageinfo"][0]))
                for p in pages if p.get("imageinfo")]


def file_info(ii):
    meta = {k: v.get("value", "") for k, v in ii.get("extmetadata", {}).items()}
    return {
        "mime": ii.get("mime"),
        "thumb": ii.get("thumburl") or ii.get("url"),
        "page": ii.get("descriptionurl"),
        "license": strip_html(meta.get("LicenseShortName", "")),
        "license_url": meta.get("LicenseUrl", ""),
        "artist": strip_html(meta.get("Artist", "")),
    }


def strip_html(text):
    text = re.sub(r"<[^>]+>", "", text or "")
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


# Artist fields that are not a name.
AUTHOR_FIXES = {
    "Sibirische_Schwertlilie,_Iris_sibirica_06.JPG": "Böhringer",
}


def clean_author(artist, file_name):
    """A short, readable credit from Commons' Artist field."""
    if file_name in AUTHOR_FIXES:
        return AUTHOR_FIXES[file_name]
    text = re.sub(r"^No machine-readable author provided\. (.*) assumed \(based on copyright claims\)\.$", r"\1", artist)
    text = re.sub(r"\S+@\S+", "", text).strip(" ,;()")
    if len(text) > 60:
        text = text[:60].rsplit(" ", 1)[0].rstrip(" ,;(") + "…"
    return text or "Unknown author"


def name_parts(sci):
    """Returns (cleaned full name, species binomial or None, genus, is_variant)."""
    s = re.sub(r"\(.*?\)", "", sci).strip()
    variant = bool(re.search(r"'|\bvar\.|\bsubsp\.|\bf\.|hybrids|\(", sci))
    s_no_cv = re.sub(r"'[^']*'", "", s).replace(" hybrids", "").strip()
    s_no_cv = re.sub(r"\s+x\s+", " × ", s_no_cv)
    words = s_no_cv.split()
    genus = words[0]
    binomial = None
    if len(words) >= 2 and words[1] not in ("spp.", "subg.") and (words[1] == "×" or words[1][0].islower()):
        binomial = " ".join(words[:3]) if words[1] == "×" else " ".join(words[:2])
    if "spp." in words or "subg." in words:
        s_no_cv = genus
    return s_no_cv, binomial, genus, variant


def candidates(plant, shared):
    pid = plant["id"]
    if pid in OVERRIDES:
        return [(t, "override") for t in (OVERRIDES[pid] or [])]
    sci = plant["scientific_name"][0]
    full, binomial, genus, variant = name_parts(sci)
    common = plant["common_name"]
    common_cap = common[0].upper() + common[1:]
    cv = re.search(r"'([^']*)'", sci)
    sci_titles = [full] + ([binomial] if binomial and binomial != full else [])
    common_titles = [common_cap, f"{common_cap} (plant)"]
    if cv:
        common_titles += [f"{cv.group(1)} ({common.split()[-1]})", cv.group(1)]
    # Crops, cultivars and species shared by several plants (broccoli, kale and
    # cabbage are all Brassica oleracea) look best on their own article.
    if variant or (binomial in shared) or plant["collection"] == "kitchen":
        order = [(t, "common") for t in common_titles] + [(t, "sci") for t in sci_titles]
    else:
        order = [(t, "sci") for t in sci_titles] + [(t, "common") for t in common_titles]
    order.append((genus, "genus"))
    seen, out = set(), []
    for t, kind in order:
        if t not in seen:
            seen.add(t)
            out.append((t, kind))
    return out


def plausible(page, kind, plant):
    """Is this article about the plant? Scientific-name hits are; a common-name
    hit has to name the genus, be titled with the plant's own name, or be
    titled with the cultivar's name and describe a cultivar."""
    if page is None or page["disambiguation"]:
        return False
    if kind in ("sci", "override"):
        return True
    sci = plant["scientific_name"][0]
    genus = sci.split()[0].lower()
    intro = page["extract"].lower()
    title = re.sub(r"\s*\(.*\)", "", page["title"]).lower()
    if kind == "genus":
        return title == genus
    if genus in intro:
        return True
    crop = plant["common_name"].split()[-1].lower()
    if title == plant["common_name"].lower():
        return True
    cv = re.search(r"'([^']*)'", sci)
    return bool(cv and cv.group(1).lower() in title and crop in intro
                and re.search(r"cultivar|variety", intro))


# Old botanical plates and line drawings: fine when nothing else exists, but a
# photo is better.
ILLUSTRATION = re.compile(r"k(ö|oe)hler|koeh-|illustration|curtis|flore_des|walcott|usda|britton|thom[eé]|plate|blanco1|heinrichflora|botanical_magazine", re.I)


def usable(f):
    return bool(f) and f["mime"] in ("image/jpeg", "image/png") and FREE.match(f["license"])


def choose(plant, cands, pages, files, p18):
    """Best (title, kind, file name, info): photos from the plant's own
    articles, then drawings, then the genus article."""
    options = []
    for title, kind in cands:
        page = pages.get(title)
        if not plausible(page, kind, plant):
            continue
        for name in (page["image"], p18.get(page["item"])):
            if name and name not in BAD_FILES and usable(files.get(name)):
                options.append((title, kind, page, name, files[name]))
    for wanted in (lambda o: o[1] != "genus" and not ILLUSTRATION.search(o[3]),
                   lambda o: o[1] != "genus",
                   lambda o: not ILLUSTRATION.search(o[3]),
                   lambda o: True):
        for o in options:
            if wanted(o):
                return o
    return None


def commons_photo(wiki, plant):
    """Search Commons for a photo when the articles only offer a drawing, a
    relative from the same genus, or nothing. Searches by species name (plus
    the common name for 'spp.' plants) and keeps a hit whose file name names
    the species or the plant."""
    full, binomial, genus, _ = name_parts(plant["scientific_name"][0])
    query = binomial or f"{genus} {plant['common_name']}"
    words = [w.lower() for w in (binomial or plant["common_name"]).replace("×", "").split()]
    for name, f in wiki.search(query):
        key = name.lower().replace("_", " ")
        if (name not in BAD_FILES and usable(f) and not ILLUSTRATION.search(name)
                and all(w in key for w in words)):
            return (f"commons search: {query}", "search", None, name, f)
    return None


def main(ui_root, dry_run=False):
    wiki = Wiki()
    index = json.load(open(INDEX))
    plants = [p for p in index["data"] if p["id"] >= FIRST_BUILT_IN]
    binomials = [name_parts(p["scientific_name"][0])[1] for p in plants]
    shared = {b for b in binomials if b and binomials.count(b) > 1}

    cands = {p["id"]: candidates(p, shared) for p in plants}
    pages = wiki.pages([t for cs in cands.values() for t, _ in cs])
    p18 = wiki.wikidata_images(pg["item"] for pg in pages.values() if pg)
    names = {pg["image"] for pg in pages.values() if pg and pg["image"]} | set(p18.values())
    files = wiki.files(names)
    wiki.save()

    out_dir = os.path.join(ui_root, "public", "images", "plants")
    os.makedirs(out_dir, exist_ok=True)
    chosen = {}
    for p in plants:
        pick = choose(p, cands[p["id"]], pages, files, p18)
        if (not pick or pick[1] == "genus" or ILLUSTRATION.search(pick[3])) and p["id"] not in OVERRIDES:
            found = commons_photo(wiki, p)
            pick = found or pick
        if pick:
            chosen[p["id"]] = pick
        print(f"{p['id']}\t{p['collection']}\t{p['common_name']}\t"
              + (f"{pick[1]}:{pick[0]}\t{pick[3]}\t{pick[4]['license']}" if pick else "NONE"))
    print(f"{len(chosen)}/{len(plants)} with photos; {wiki.calls} API calls", file=sys.stderr)
    if dry_run:
        return 0

    for p in plants:
        path = f"{DETAILS_DIR}/{p['id']}.json"
        details = json.load(open(path))
        local = f"/images/plants/{p['id']}.jpg"
        dest = os.path.join(out_dir, f"{p['id']}.jpg")
        if p["id"] not in chosen:
            if os.path.exists(dest):
                os.remove(dest)
            continue
        _, _, _, name, f = chosen[p["id"]]
        if details.get("image_credit", {}).get("source_url") != f["page"] or not os.path.exists(dest):
            download(f["thumb"], dest, wiki)
        details["default_image"] = {k: local for k in ("thumbnail", "small_url", "medium_url", "regular_url")}
        details["image_credit"] = {
            "author": clean_author(f["artist"], name),
            "license": f["license"],
            "license_url": f["license_url"] or f["page"],
            "source_url": f["page"],
        }
        with open(path, "w") as fh:
            fh.write(json.dumps(details, indent=2, ensure_ascii=False) + "\n")
        p["default_image"] = {"thumbnail": local}
    with open(INDEX, "w") as fh:
        fh.write(json.dumps(index, indent=4, ensure_ascii=False) + "\n")
    wiki.save()
    return 0


def shrink(data):
    """Re-encode as a small JPEG: at most WIDTH wide, tall pictures cropped to
    4:3 portrait (the details page shows a landscape box anyway). Without
    Pillow the Commons thumbnail is kept as is."""
    try:
        from PIL import Image
    except ImportError:
        return data
    img = Image.open(io.BytesIO(data)).convert("RGB")
    if img.width > WIDTH:
        img = img.resize((WIDTH, round(img.height * WIDTH / img.width)), Image.LANCZOS)
    max_h = round(img.width * 4 / 3)
    if img.height > max_h:
        top = (img.height - max_h) // 2
        img = img.crop((0, top, img.width, top + max_h))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=66, optimize=True, progressive=True)
    return buf.getvalue()


def download(url, dest, wiki):
    wait = 1.0 - (time.time() - wiki.last)
    if wait > 0:
        time.sleep(wait)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    wiki.last = time.time()
    data = shrink(data)
    with open(dest, "wb") as fh:
        fh.write(data)
    print(f"saved {dest} ({len(data)} bytes)")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    if "--shrink-existing" in sys.argv:  # re-run shrink() over saved photos
        for path in glob.glob(os.path.join(sys.argv[1], "public/images/plants/9*.jpg")):
            small = shrink(open(path, "rb").read())
            if len(small) < os.path.getsize(path):
                open(path, "wb").write(small)
        sys.exit(0)
    sys.exit(main(sys.argv[1], "--dry-run" in sys.argv))
