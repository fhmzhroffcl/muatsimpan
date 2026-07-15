#!/usr/bin/env python3
"""Copies the maintained landing template to index.html.

The site now keeps media as external, cacheable assets instead of embedding
large base64 payloads in the document.
"""
import os, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

template = os.path.join(HERE, "template.html")
out_path = os.path.join(HERE, "index.html")
shutil.copyfile(template, out_path)
print(f"Built {out_path} ({os.path.getsize(out_path)//1024} KB)")
raise SystemExit(0)

def first_existing(*names):
    for n in names:
        p = os.path.join(ROOT, n)
        if os.path.exists(p): return p
    raise FileNotFoundError(names[0])

# --- brand assets ---
assets = {
    "__ICON__": b64(first_existing("build/icon-1024.png", "must simpan ico.png", "MuatSimpan.png"), "image/png"),
    "__HERO__": b64(os.path.join(HERE, "assets", "hero.mp4"), "video/mp4"),
    "__QR__":   b64(first_existing("fahim QR.png"), "image/png"),
}

# --- platform logos (real brand PNGs) ---
PLATS = ["youtube","facebook","instagram","tiktok","vimeo","twitch","soundcloud","reddit","x","bilibili"]
plat_data = {}
for p in PLATS:
    fp = os.path.join(HERE, "assets", "plat", f"{p}.png")
    if os.path.exists(fp):
        plat_data[p] = b64(fp, "image/png")

# --- inline SVG icons (match the app's SF-Symbol-style set) ---
def svg(paths, fill=False):
    attr = ('fill="currentColor" stroke="none"' if fill else
            'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"')
    return f'<svg viewBox="0 0 24 24" {attr}>{paths}</svg>'

ICONS = {
    "ICO_DL":    svg('<path d="M12 3v13"/><path d="M7 12l5 5 5-5"/><path d="M5 21h14"/>'),
    "ICO_LIB":   svg('<rect x="3" y="4" width="18" height="15" rx="2.5"/><path d="M3 9.5h18"/>'),
    "ICO_GLOBE": svg('<circle cx="12" cy="12" r="9"/><path d="M3.5 9h17M3.5 15h17M12 3c-3 3-3 15 0 18M12 3c3 3 3 15 0 18"/>'),
    "ICO_GEAR":  svg('<circle cx="12" cy="12" r="3.4"/><path d="M12 2.5v3M12 18.5v3M4.2 7l2.6 1.5M17.2 15.5l2.6 1.5M4.2 17l2.6-1.5M17.2 8.5l2.6-1.5"/>'),
    "ICO_SPARK": svg('<path d="M12 3l1.8 4.7L18.5 9.5 13.8 11.3 12 16l-1.8-4.7L5.5 9.5l4.7-1.8z"/><path d="M18.5 4v3M20 5.5h-3" stroke-width="1.4"/>'),
    "ICO_INFO":  svg('<circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><circle cx="12" cy="7.8" r="1" fill="currentColor" stroke="none"/>'),
    "ICO_LINK":  svg('<path d="M9 15l6-6"/><path d="M11 7l1-1a3.5 3.5 0 015 5l-1 1"/><path d="M13 17l-1 1a3.5 3.5 0 01-5-5l1-1"/>'),
    "ICO_FILM":  svg('<rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M8 5v14M16 5v14M3 12h18"/>'),
    "ICO_MUSIC": svg('<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.4"/><circle cx="16.5" cy="16" r="2.4"/>'),
    "ICO_FOLDER":svg('<path d="M3 7.5a2 2 0 012-2h4l2 2h8a2 2 0 012 2v7a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>'),
    "ICO_GRID":  svg('<rect x="3.5" y="3.5" width="7.5" height="7.5" rx="1.6"/><rect x="13" y="3.5" width="7.5" height="7.5" rx="1.6"/><rect x="3.5" y="13" width="7.5" height="7.5" rx="1.6"/><rect x="13" y="13" width="7.5" height="7.5" rx="1.6"/>'),
    "ICO_EDIT":  svg('<path d="M4 15.5l6-6 4 4 6-8"/><circle cx="10" cy="9.5" r="1.5"/>'),
    "ICO_NOTE":  svg('<rect x="4.5" y="3.5" width="15" height="17" rx="2.5"/><path d="M8 8.5h8M8 12h8M8 15.5h5"/>'),
    "ICO_LOCK":  svg('<rect x="5" y="11" width="14" height="9" rx="2.5"/><path d="M8 11V8a4 4 0 018 0v3"/>'),
    "ICO_PLAYC": svg('<circle cx="12" cy="12" r="9"/><path d="M10 8.2l6 3.8-6 3.8z" fill="currentColor" stroke="none"/>'),
    "ICO_EXPORT":svg('<path d="M12 15V4"/><path d="M8 8l4-4 4 4"/><path d="M5 15v4a1 1 0 001 1h12a1 1 0 001-1v-4"/>'),
}

# feature-icon helper: __FI(ICO_X)__ -> <div class="fi">SVG</div>
def fi_replace(html):
    return re.sub(r"__FI\((\w+)\)__", lambda m: f'<div class="fi">{ICONS[m.group(1)]}</div>', html)

# --- site cards for the mockup (brand colour bar + real logo) ---
BRAND = {"youtube":"#FF0000","tiktok":"#25F4EE","instagram":"#E1306C","x":"#1DA1F2",
         "facebook":"#1877F2","vimeo":"#1AB7EA","twitch":"#9146FF","soundcloud":"#FF5500",
         "reddit":"#FF4500","bilibili":"#00A1D6"}
NAMES = {"youtube":"YouTube","tiktok":"TikTok","instagram":"Instagram","x":"X","facebook":"Facebook",
         "vimeo":"Vimeo","twitch":"Twitch","soundcloud":"SoundCloud","reddit":"Reddit","bilibili":"Bilibili"}
def site_cards():
    out = []
    for p in ["youtube","tiktok","instagram","facebook","x","vimeo","twitch","soundcloud","reddit"]:
        if p not in plat_data: continue
        out.append(
            f'<div class="mcell" style="aspect-ratio:auto;display:flex;align-items:center;gap:9px;'
            f'padding:10px;justify-content:flex-start;border-left:3px solid {BRAND[p]}">'
            f'<img src="{plat_data[p]}" style="width:22px;height:22px;object-fit:contain">'
            f'<span style="font-size:12px;font-weight:600;color:var(--text)">{NAMES[p]}</span></div>')
    return "\n".join(out)

# --- marquee of platform logos ---
def marquee():
    return "".join(f'<img src="{plat_data[p]}" alt="{NAMES.get(p,p)}">' for p in PLATS if p in plat_data)

# --- legal markdown -> simple HTML ---
def fmt(t):
    t = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"\*(.+?)\*", r"<em>\1</em>", t)
    t = re.sub(r"`(.+?)`", r"<code>\1</code>", t)
    return t

def md_to_html(path):
    out, in_list = [], False
    for raw in open(path, encoding="utf-8"):
        s = raw.rstrip("\n").strip()
        def close():
            nonlocal in_list
            if in_list: out.append("</ul>"); in_list = False
        if s.startswith("# "): continue
        if s == "---": close(); out.append('<div class="divider"></div>'); continue
        if s.startswith("### "): close(); out.append(f"<h4>{fmt(s[4:])}</h4>"); continue
        if s.startswith("## "):  close(); out.append(f"<h3>{fmt(s[3:])}</h3>"); continue
        if s.startswith("- "):
            if not in_list: out.append("<ul>"); in_list = True
            out.append(f"<li>{fmt(s[2:])}</li>"); continue
        if s == "": close(); continue
        close(); out.append(f"<p>{fmt(s)}</p>")
    if in_list: out.append("</ul>")
    return "\n".join(out)

# --- assemble ---
html = open(os.path.join(HERE, "template.html"), encoding="utf-8").read()
html = fi_replace(html)
for tok, code in ICONS.items():
    html = html.replace(f"__{tok}__", code)
for p, data in plat_data.items():
    html = html.replace(f"__P_{p}__", data)
html = html.replace("__MARQUEE__", marquee())
html = html.replace("__SITECARDS__", site_cards())
for tok, data in assets.items():
    html = html.replace(tok, data)
html = html.replace("__TERMS__", md_to_html(os.path.join(ROOT, "legal", "TERMS.md")))
html = html.replace("__PRIVACY__", md_to_html(os.path.join(ROOT, "legal", "PRIVACY.md")))
html = html.replace("__DMG_URL__", "")   # paste the Google Drive DMG link here later

out_path = os.path.join(HERE, "index.html")
with open(out_path, "w", encoding="utf-8") as f:
    f.write(html)
print(f"Built {out_path} ({os.path.getsize(out_path)//1024} KB)")
