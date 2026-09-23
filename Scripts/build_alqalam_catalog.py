#!/usr/bin/env python3
"""Build AlQalamCatalog.json + Library chapter JSON from downloaded SRTs."""
from __future__ import annotations

import html as H
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import unquote, urlparse

NUR = Path(__file__).resolve().parents[1]
ROOT = NUR / "Shared/Resources/AlQalam"
SRT_DIR = ROOT / "srt"
TX_DIR = ROOT / "transcripts"
LIB = NUR / "Shared/Resources/Library"
MEDIA_INDEX = Path("/tmp/alqalam/media-index.json")
YT_PAIR = Path("/tmp/alqalam/yt-pair.json")


def srt_to_lines(raw: str) -> List[str]:
    """Extract cue text lines from SRT, dropping indexes/timecodes/dupes."""
    lines: List[str] = []
    for line in raw.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        t = line.replace("\ufeff", "").strip()
        if not t:
            continue
        if re.fullmatch(r"\d+", t):
            continue
        if re.match(
            r"\d{1,2}:\d{2}:\d{2}[,\.]\d{1,3}\s*-->\s*\d{1,2}:\d{2}:\d{2}", t
        ):
            continue
        t = re.sub(r"<[^>]+>", "", t)
        t = H.unescape(t).strip()
        t = t.replace("\ufeff", "").strip()
        if t:
            lines.append(t)
    out: List[str] = []
    prev = None
    for L in lines:
        if L != prev:
            out.append(L)
            prev = L
    return out


_URDU_CHARS = re.compile(r"[\u0679\u067E\u0686\u0688\u0691\u06A9\u06AF\u06BE\u06C1\u06D2\u06BA]")
_ARABIC_CHARS = re.compile(r"[\u0600-\u06FF]")
_LATIN_CHARS = re.compile(r"[A-Za-z]")


def line_script(line: str) -> str:
    """Classify a subtitle line: arabic | urdu | english."""
    ar = len(_ARABIC_CHARS.findall(line))
    lat = len(_LATIN_CHARS.findall(line))
    urdu_marks = len(_URDU_CHARS.findall(line))
    if ar == 0:
        return "english"
    # English narration with parenthetical glosses: "Sahabah(صحابہ)" / "Karamat(کرامات)"
    if lat > max(ar * 1.2, 8):
        return "english"
    if urdu_marks >= 2 or (urdu_marks >= 1 and ar >= lat and ar >= 8):
        return "urdu"
    if ar >= lat:
        return "arabic"
    return "english"


def join_prose(lines: List[str]) -> str:
    """Join short subtitle cues into readable paragraphs."""
    if not lines:
        return ""
    paras: List[str] = []
    buf = ""
    for L in lines:
        if not buf:
            buf = L
        else:
            # no space before Arabic continuation marks
            if buf[-1] in "([{/-" or L[0] in ".,;:!?)]}":
                buf = buf + L
            else:
                buf = buf + " " + L
        if len(buf) >= 140 or buf.endswith((".", "?", "!", "۔", "؟", "۞", "۝")):
            paras.append(buf.strip())
            buf = ""
    if buf.strip():
        paras.append(buf.strip())
    return "\n\n".join(paras)


def srt_to_parts(raw: str) -> Dict[str, str]:
    """Split one SRT into english / urdu / arabic prose fields."""
    buckets: Dict[str, List[str]] = {"english": [], "urdu": [], "arabic": []}
    for line in srt_to_lines(raw):
        buckets[line_script(line)].append(line)
    return {k: join_prose(v) for k, v in buckets.items()}


def srt_to_text(raw: str) -> str:
    """Legacy flat text (english-preferring join of all lines)."""
    parts = srt_to_parts(raw)
    # Prefer natural reading order: arabic duas, then body lang
    chunks = [parts[k] for k in ("arabic", "english", "urdu") if parts[k]]
    return "\n\n".join(chunks)


def has_arabic(s: str) -> bool:
    return bool(_ARABIC_CHARS.search(s))


def is_urdu_dominant(text: str) -> bool:
    if not text:
        return False
    return bool(_URDU_CHARS.search(text)) or (
        line_script(text[:400]) == "urdu"
    )


def classify_series(url: str, title: str, fname: str) -> str:
    blob = f"{url} {title} {fname}"
    u = blob.lower()
    f = fname

    if "boj" in u or "dust-will" in u or "dust_will" in u:
        return "anwar-boj"
    if "dream" in u:
        return "anwar-dreams"
    if "palestine" in u or "tamimi" in u or "christian" in u or "missionar" in u:
        return "anwar-misc-extra"
    if "hereafter" in u or "here-after" in u or "here after" in u:
        return "anwar-hereafter"

    abu_keys = (
        "abu-bakr",
        "abu_bakr",
        "abubakr",
        "apostates",
        "appostates",
        "baiyah",
        "inaugural",
        "usama",
        "governers-the-army",
        "conquest-of-iraq",
        "war-against-romans",
        "yarmook",
        "khaleefah",
        "death-of-rasool",
        "virtues-of-abu-bakr",
        "family-background-islam-of-abu",
        "hijrah-of-abu-bakr",
        "jihad-with-the-messenger",
        "life-in-madinah",
        "ابوبکر",
        "صدیق",
        "مُرتد",
        "مرتد",
        "غزوۃ",
        "یرموک",
        "بیعۃ",
        "اسامہ",
        "فضائل",
        "رحلتِ-رسول",
        "خلیفۃ",
        "سیرتِ-حضرت-ابوبکر",
    )
    if any(k in u or k in f for k in abu_keys) or "ابوبکر" in f or "صدیق" in f or "سیرتِ" in f:
        return "anwar-abu-bakr"

    umar_keys = (
        "umar",
        "khattab",
        "men-around-the-messenger",
        "ameer-ul-momineen",
        "nightly-patrols",
        "land-of-pharaoh",
        "aam-er-ramadah",
        "byzantine",
        "muslim-army",
        "frontier-lands",
        "courts-of-umar",
        "governers-of-umar",
        "government-of-umar",
        "virtues-of-umar",
        "jihad-of-umar",
        "conquest-of-umar",
        "last-days-of-umar",
        "عمر",
        "خطاب",
        "یاران",
    )
    if any(k in u for k in umar_keys) or "عمر" in f or "خطاب" in f or "یاران" in f:
        return "anwar-umar"

    if "حیاتِ_انبیاء" in f or "حیاتِ انبیاء" in f or "lives_of_the_prophets" in u:
        return "anwar-lives-prophets"

    prophet_keys = (
        "adam",
        "musa",
        "ibrahim",
        "yusuf",
        "sulaiman",
        "imran",
        "firaun",
        "firaoun",
        "dawood",
        "daud",
        "ayub",
        "yunus",
        "shoaib",
        "shuaib",
        "saleh",
        "sheith",
        "idris",
        "yusha",
        "story-of-creation",
        "family-of-imran",
        "queen-sheba",
        "bani-israel",
        "bani-israe",
        "dawah-of-ibrahim",
        "cont-adam",
    )
    seerah_keys = (
        "seerah",
        "muhammad",
        "makkah",
        "madina",
        "madinah",
        "badr",
        "uhud",
        "hudaybiyyah",
        "khaybar",
        "tabook",
        "fath-e-makkah",
        "trench",
        "khandaq",
        "hijrah",
        "revelation",
        "glad-tidings",
        "emmigrant",
        "immigrant",
        "reaction",
        "background-history",
        "early-life",
        "important-events",
        "persuit",
        "pursuit",
        "religious-situation",
        "pre-islamic",
        "establishment-of-the-state",
        "in-search-of-base",
        "road-to-madina",
        "bannu",
        "mustalaq",
        "quraidha",
        "hawazin",
        "hunain",
        "maota",
        "nifaq",
        "farewell-hajj",
        "last-days-of-rasool",
        "kaab-ibn-malik",
        "amr-bin-aas",
        "letter-to-the-kings",
    )

    # Seerah first so Uhud / Hudaybiyyah are not stolen by short prophet tokens (hud).
    if any(k in u for k in seerah_keys):
        return "anwar-seerah"

    def has_prophet_signal(text: str) -> bool:
        t = text.lower()
        if "land-of-pharaoh" in t:
            return False
        if any(k in t for k in prophet_keys):
            return True
        return bool(re.search(r"(?<![a-z])(hud|nuh|lut|salih)(?![a-z])", t))

    if has_prophet_signal(u):
        return "anwar-lives-prophets"

    # Numbered `N.-Title` without keywords: high numbers → seerah, low → check remaining
    m = re.match(r"^(\d{1,2})\.-", fname)
    if m:
        return "anwar-seerah"

    return "anwar-uncategorized"


def lecture_num(fname: str, title: str) -> Optional[int]:
    for src in (fname, title):
        m = re.match(r"^(\d{1,2})[\.\-_\s]", src)
        if m:
            return int(m.group(1))
        m = re.search(r"part[_\s\-]*(\d{1,2})", src, re.I)
        if m:
            return int(m.group(1))
        m = re.search(r"(\d{1,2})\s*of\s*\d+", src, re.I)
        if m:
            return int(m.group(1))
        m = re.search(r"(?:boj|cd)[.\s_-]*(\d{1,2})", src, re.I)
        if m:
            return int(m.group(1))
    m = re.search(r"(\d{1,2})(?:\.srt)?$", fname)
    if m:
        return int(m.group(1))
    return None


def nice_title(fname: str, title: str) -> str:
    t = title.strip() if title and title.lower() not in ("", "srt") else fname
    t = re.sub(r"\.srt$", "", t, flags=re.I)
    t = t.replace("_", " ").replace("-", " ")
    t = re.sub(r"\s+", " ", t).strip()
    return t


SERIES_META = {
    "anwar-seerah": (
        "Life of Muhammad ﷺ (Al Qalam)",
        "Seerah · SRT + transcripts · YouTube where available",
        "book.fill",
    ),
    "anwar-lives-prophets": (
        "Lives of the Prophets (Al Qalam)",
        "Full series · English/Urdu SRT",
        "sparkles",
    ),
    "anwar-abu-bakr": (
        "Abu Bakr as-Siddiq (Al Qalam)",
        "Biography · EN + UR subtitles",
        "person.fill",
    ),
    "anwar-umar": (
        "Umar ibn al-Khattab (Al Qalam)",
        "Biography · EN + UR subtitles",
        "shield.fill",
    ),
    "anwar-hereafter": (
        "The Hereafter (Al Qalam)",
        "Hereafter lectures · transcripts",
        "moon.stars.fill",
    ),
    "anwar-boj": (
        "Book of Jihad / Misc (Al Qalam)",
        "BOJ + Dust Will Never Settle",
        "flag.fill",
    ),
    "anwar-dreams": (
        "Dream Interpretations (Al Qalam)",
        "Dream series",
        "moon.zzz.fill",
    ),
    "anwar-misc-extra": (
        "Additional Lectures (Al Qalam)",
        "Palestine, missionaries, extras",
        "square.stack.fill",
    ),
    "anwar-uncategorized": ("Other Al Qalam assets", "Needs review", "questionmark.circle"),
}


def main() -> None:
    TX_DIR.mkdir(parents=True, exist_ok=True)
    index = json.loads(MEDIA_INDEX.read_text())
    manifest = json.loads((ROOT / "srt-manifest.json").read_text())
    url_to_file = {
        m["url"]: m.get("file") for m in manifest if m.get("file") and not m.get("error")
    }
    yt_list = []
    if YT_PAIR.exists():
        yt_list = [p["youtube"] for p in json.loads(YT_PAIR.read_text())]

    lectures: List[Dict[str, Any]] = []
    for m in index["media"]:
        if m["kind"] != "srt":
            continue
        url = m["url"]
        fname = unquote(urlparse(url).path.split("/")[-1])
        file = url_to_file.get(url)
        if not file:
            safe = "".join(c if c.isalnum() or c in "._-()[] " else "_" for c in fname)
            if (SRT_DIR / safe).exists():
                file = safe
        lang = (
            "urdu"
            if has_arabic(fname) or "urdu" in fname.lower() or "اردو" in fname
            else "english"
        )
        series = classify_series(url, m["title"], fname)
        num = lecture_num(fname, m["title"])
        text = ""
        parts: Dict[str, str] = {"english": "", "urdu": "", "arabic": ""}
        if file and (SRT_DIR / file).exists():
            raw = (SRT_DIR / file).read_text(encoding="utf-8", errors="replace")
            parts = srt_to_parts(raw)
            # Correct language label from content (filename can lie)
            if is_urdu_dominant(parts["urdu"]) and len(parts["urdu"]) > len(parts["english"]):
                lang = "urdu"
            elif parts["english"] and lang == "urdu" and not is_urdu_dominant(parts["urdu"]):
                lang = "english"
            text = srt_to_text(raw)
            slug = re.sub(r"[^a-zA-Z0-9_\-]+", "_", Path(file).stem)[:80]
            tx_name = f"{series}__{lang}__{(num or 0):02d}__{slug}.txt"
            (TX_DIR / tx_name).write_text(text, encoding="utf-8")
        lectures.append(
            {
                "series": series,
                "lang": lang,
                "index": num,
                "title": nice_title(fname, m["title"]),
                "srtFile": file,
                "srtUrl": url,
                "mediaId": m["id"],
                "transcriptChars": len(text),
                "parts": parts,
                "youtubeId": None,
            }
        )

    seerah_en = [
        L
        for L in lectures
        if L["series"] == "anwar-seerah" and L["lang"] == "english" and L["index"]
    ]
    by_idx: Dict[int, Dict[str, Any]] = {}
    for L in seerah_en:
        i = L["index"]
        if i not in by_idx or L["transcriptChars"] > by_idx[i]["transcriptChars"]:
            by_idx[i] = L
    ordered = sorted(by_idx.values(), key=lambda x: x["index"])
    for i, L in enumerate(ordered[: len(yt_list)]):
        L["youtubeId"] = yt_list[i]

    docs = [m for m in index["media"] if m["kind"] == "transcript_doc"]
    doc_links: Dict[Tuple[Any, Any, Any], List[Dict[str, str]]] = defaultdict(list)
    for d in docs:
        fname = unquote(urlparse(d["url"]).path.split("/")[-1])
        series = classify_series(d["url"], d["title"], fname)
        num = lecture_num(fname, d["title"])
        lang = (
            "urdu"
            if has_arabic(fname + d["title"]) or "urdu" in (fname + d["title"]).lower()
            else "english"
        )
        doc_links[(series, num, lang)].append(
            {"title": H.unescape(d["title"]), "url": d["url"]}
        )

    for L in lectures:
        key = (L["series"], L["index"], L["lang"])
        if key in doc_links:
            L["docs"] = doc_links[key]

    series_map: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for L in lectures:
        series_map[L["series"]].append(L)

    catalog: Dict[str, Any] = {
        "source": "https://alqalamhistory.com/",
        "attribution": "Al Qalam · Imam Anwar al-Awlaki lecture transcripts & subtitles",
        "counts": {
            "srt": len(lectures),
            "withTranscript": len([L for L in lectures if L["transcriptChars"] > 0]),
            "withYoutube": len([L for L in lectures if L.get("youtubeId")]),
            "docs": len(docs),
            "srtOnDisk": len(list(SRT_DIR.glob("*.srt"))),
            "srtFailed": sum(1 for m in manifest if m.get("error")),
        },
        "series": [],
        "assets": lectures,
        "docs": [
            {
                "title": H.unescape(d["title"]),
                "url": d["url"],
                "series": classify_series(
                    d["url"],
                    d["title"],
                    unquote(urlparse(d["url"]).path.split("/")[-1]),
                ),
                "index": lecture_num(
                    unquote(urlparse(d["url"]).path.split("/")[-1]), d["title"]
                ),
            }
            for d in docs
        ],
    }

    for sid, items in sorted(series_map.items()):
        title, subtitle, icon = SERIES_META.get(sid, (sid, "", "book"))
        en = [x for x in items if x["lang"] == "english"]
        ur = [x for x in items if x["lang"] == "urdu"]
        seen = set()
        chapters = []
        for L in sorted(
            en, key=lambda x: (x["index"] is None, x["index"] or 999, x["title"])
        ):
            key = L["index"] if L["index"] is not None else L["title"]
            if key in seen:
                continue
            seen.add(key)
            cid = (
                f"aq-{L['index']:02d}"
                if L["index"] is not None
                else f"aq-{re.sub(r'[^a-z0-9]+', '-', L['title'].lower())[:40]}"
            )
            ur_twin = next((u for u in ur if u["index"] == L["index"]), None)
            chapters.append(
                {
                    "id": cid,
                    "index": L["index"],
                    "title": L["title"],
                    "youtubeId": L.get("youtubeId"),
                    "srtEnglish": L.get("srtFile"),
                    "srtUrlEnglish": L.get("srtUrl"),
                    "srtUrdu": ur_twin.get("srtFile") if ur_twin else None,
                    "srtUrlUrdu": ur_twin.get("srtUrl") if ur_twin else None,
                    "docs": L.get("docs") or [],
                    "transcriptChars": L.get("transcriptChars") or 0,
                }
            )
        catalog["series"].append(
            {
                "id": sid,
                "title": title,
                "subtitle": f"{subtitle} · {len(chapters)} lectures · {len(ur)} Urdu SRT",
                "icon": icon,
                "kind": "chapters",
                "primaryLanguage": "english",
                "attribution": catalog["attribution"],
                "chapters": chapters,
                "urduSrtCount": len(ur),
                "assetCount": len(items),
            }
        )

    (ROOT / "AlQalamCatalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    for s in catalog["series"]:
        sdir = LIB / s["id"]
        sdir.mkdir(parents=True, exist_ok=True)
        for ch in s["chapters"]:
            en_parts = {"english": "", "urdu": "", "arabic": ""}
            ur_parts = {"english": "", "urdu": "", "arabic": ""}
            if ch.get("srtEnglish") and (SRT_DIR / ch["srtEnglish"]).exists():
                en_parts = srt_to_parts(
                    (SRT_DIR / ch["srtEnglish"]).read_text(
                        encoding="utf-8", errors="replace"
                    )
                )
            if ch.get("srtUrdu") and (SRT_DIR / ch["srtUrdu"]).exists():
                ur_parts = srt_to_parts(
                    (SRT_DIR / ch["srtUrdu"]).read_text(
                        encoding="utf-8", errors="replace"
                    )
                )

            english = en_parts["english"]
            # Never park Latin prose in the Urdu field
            urdu = ur_parts["urdu"]
            if not is_urdu_dominant(urdu):
                if ur_parts["english"]:
                    english = "\n\n".join(x for x in (english, ur_parts["english"]) if x)
                urdu = ""
            # Urdu leaked into "English" SRT file
            if is_urdu_dominant(en_parts["urdu"]) and not urdu:
                urdu = en_parts["urdu"]

            arabic = "\n\n".join(
                x for x in (en_parts["arabic"], ur_parts["arabic"]) if x
            )

            body = {
                "title": ch["title"],
                "arabic": arabic,
                "english": english,
                "urdu": urdu,
                "reference": (
                    f"Al Qalam · {s['title']} · {ch['title']}"
                    + (
                        f" · https://youtube.com/watch?v={ch['youtubeId']}"
                        if ch.get("youtubeId")
                        else ""
                    )
                ),
                "youtubeId": ch.get("youtubeId"),
                "srtEnglish": ch.get("srtEnglish"),
                "srtUrdu": ch.get("srtUrdu"),
                "source": "https://alqalamhistory.com/",
            }
            (sdir / f"{ch['id']}.json").write_text(
                json.dumps(body, ensure_ascii=False, indent=2), encoding="utf-8"
            )

    print("CATALOG series:")
    for s in catalog["series"]:
        yt = sum(1 for c in s["chapters"] if c.get("youtubeId"))
        print(
            f"  {s['id']}: {len(s['chapters'])} chapters, assets={s['assetCount']}, "
            f"ur={s['urduSrtCount']}, yt={yt}"
        )
    print("counts", catalog["counts"])
    print("transcript txts", len(list(TX_DIR.glob("*.txt"))))
    print("chapter jsons", len(list(LIB.glob("anwar-*/aq-*.json"))))


if __name__ == "__main__":
    main()
