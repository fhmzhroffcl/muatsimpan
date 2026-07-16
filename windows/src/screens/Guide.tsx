import { useEffect, useRef, useState } from "react";
import { useApp } from "../lib/store";
import { Icon } from "../ui/Icon";

// Scroll-led tour mirroring the real Musim flow (port of PanduanView).
interface Chapter { n: string; my: string; en: string; myBody: string; enBody: string; icon: string; }

const CHAPTERS: Chapter[] = [
  { n: "01", my: "Mula dengan koleksi anda", en: "Start with your collection", myBody: "Pustaka menjadi tempat utama untuk semua media yang anda simpan.", enBody: "Library is the home for everything you save.", icon: "library" },
  { n: "02", my: "Tambah ke arkib", en: "Add to archive", myBody: "Bila anda mahu menambah sesuatu, pilih Tambah ke arkib.", enBody: "When you want to add something, choose Add to archive.", icon: "plus" },
  { n: "03", my: "Tampal pautan", en: "Paste a link", myBody: "Letakkan pautan video atau audio di ruang simpanan.", enBody: "Place a video or audio link in the save field.", icon: "external" },
  { n: "04", my: "Semak media", en: "Review the media", myBody: "Musim membaca tajuk, jenis media, format, dan pilihan yang tersedia.", enBody: "Musim reads the title, media type, format, and available choices.", icon: "search" },
  { n: "05", my: "Pilih video atau audio", en: "Choose video or audio", myBody: "Pilih bentuk yang sesuai dengan cara anda mahu menyimpan media itu.", enBody: "Choose the form that fits how you want to keep it.", icon: "film" },
  { n: "06", my: "Pilih kualiti dan format", en: "Choose quality and format", myBody: "Semak pilihan kualiti dan format sebelum menyimpan.", enBody: "Review quality and format options before saving.", icon: "grid" },
  { n: "07", my: "Tetapkan lokasi simpanan", en: "Set the save location", myBody: "Fail disimpan terus dalam folder yang anda pilih pada peranti.", enBody: "Files go directly into the folder you choose on your device.", icon: "folder" },
  { n: "08", my: "Simpan ke arkib", en: "Save to archive", myBody: "Tekan Simpan. Musim akan menguruskan proses dan menunjukkan kemajuan.", enBody: "Press Save. Musim handles the process and shows its progress.", icon: "archive" },
  { n: "09", my: "Pantau aktiviti", en: "Follow activity", myBody: "Aktiviti menunjukkan simpanan yang sedang berjalan dan yang sudah selesai.", enBody: "Activity shows saves in progress and those that are complete.", icon: "library" },
  { n: "10", my: "Cari dalam Pustaka", en: "Find it in Library", myBody: "Media baharu muncul bersama saiz, format, tarikh arkib, dan sumbernya.", enBody: "New media appears with its size, format, archive date, and source.", icon: "search" },
  { n: "11", my: "Main atau sunting dalam app", en: "Play or edit in the app", myBody: "Buka media dalam pemain terbina dalam atau editor untuk kerja seterusnya.", enBody: "Open media in the built-in player or editor for the next step.", icon: "play" },
  { n: "12", my: "Simpanan anda, kawalan anda", en: "Your archive, your control", myBody: "Fail kekal pada peranti dan dalam folder yang anda miliki.", enBody: "Files stay on your device and in a folder you own.", icon: "check" },
];

const SOURCES = ["YT", "FB", "TT", "IG", "X", "SC", "VM", "RD"];

export function Guide() {
  const { settings } = useApp();
  const my = settings.language === "malay";
  const [active, setActive] = useState(0);
  const [revealed, setRevealed] = useState<Set<number>>(new Set([0]));
  const refs = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => {
    const obs = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          const i = Number((e.target as HTMLElement).dataset.idx);
          if (e.isIntersecting) {
            setActive(i);
            setRevealed((r) => {
              const n = new Set(r);
              for (let k = 0; k <= i; k++) n.add(k);
              return n;
            });
          }
        }
      },
      { rootMargin: "-40% 0px -50% 0px" }
    );
    refs.current.forEach((el) => el && obs.observe(el));
    return () => obs.disconnect();
  }, []);

  return (
    <div style={{ height: "100%", overflow: "auto" }}>
      <div style={{ padding: "54px 44px 110px", maxWidth: 860, margin: "0 auto" }}>
        {/* Hero */}
        <div style={{ marginBottom: 40 }}>
          <div style={{ display: "flex", gap: 6, alignItems: "center", fontSize: 11, fontWeight: 700, letterSpacing: 1.8, color: "var(--accent)" }}>
            <Icon name="guide" size={13} /> {my ? "PANDUAN" : "GUIDE"}
          </div>
          <h1 style={{ fontSize: 40, fontWeight: 800, margin: "16px 0" }}>{my ? "Dari pautan ke simpanan milik anda." : "From a link to media you own."}</h1>
          <p style={{ fontSize: 16, color: "var(--text-secondary)", maxWidth: 720, lineHeight: 1.5 }}>
            {my ? "Ikuti perjalanan penuh Musim. Setiap bab akan hidup apabila anda scroll—daripada ruang Tambah ke arkib hingga pemain, editor, dan Pustaka." : "Follow the full Musim journey. Each chapter comes alive as you scroll—from Add to archive to the player, editor, and Library."}
          </p>
          <div style={{ display: "flex", gap: 10, marginTop: 16 }}>
            <Badge icon="library" label={my ? "12 bab interaktif" : "12 interactive chapters"} />
            <Badge icon="chevronDown" label={my ? "Ikut scroll" : "Scroll-led"} />
            <Badge icon="grid" label={my ? "Dalam app" : "Inside the app"} />
          </div>
        </div>

        {/* Progress */}
        <div style={{ position: "sticky", top: 0, background: "var(--bg)", paddingTop: 8, paddingBottom: 16, zIndex: 2 }}>
          <div style={{ display: "flex", justifyContent: "space-between", fontSize: 10, fontWeight: 700, fontFamily: "monospace", letterSpacing: 1.4, marginBottom: 8 }}>
            <span style={{ color: "var(--text-secondary)" }}>{my ? "JELAJAHKAN ALIRAN" : "EXPLORE THE FLOW"}</span>
            <span style={{ color: "var(--accent)" }}>{active + 1} / {CHAPTERS.length}</span>
          </div>
          <div style={{ height: 4, background: "var(--border)", borderRadius: 999 }}>
            <div style={{ width: `${((active + 1) / CHAPTERS.length) * 100}%`, height: "100%", borderRadius: 999, background: "linear-gradient(90deg,var(--accent),var(--accent2))", transition: "width .4s" }} />
          </div>
        </div>

        {/* Chapters */}
        <div>
          {CHAPTERS.map((c, i) => (
            <div key={i} data-idx={i} ref={(el) => (refs.current[i] = el)} style={{ display: "flex", gap: 16, alignItems: "flex-start" }}>
              <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
                <div style={{ width: 34, height: 34, borderRadius: 999, display: "grid", placeItems: "center", fontSize: 10, fontWeight: 700, fontFamily: "monospace", color: i <= active ? "#fff" : "var(--text-secondary)", background: i <= active ? "var(--accent)" : "var(--surface)" }}>{c.n}</div>
                {i < CHAPTERS.length - 1 && <div style={{ width: 2, height: 22, background: i < active ? "var(--accent)" : "var(--border)" }} />}
              </div>
              <div
                style={{
                  flex: 1, marginBottom: 12, padding: 20, borderRadius: 12,
                  background: "var(--surface)", border: `${i === active ? 1.5 : 1}px solid ${i === active ? "var(--accent)" : "var(--border)"}`,
                  opacity: revealed.has(i) ? 1 : 0.22, transform: revealed.has(i) ? "none" : "translateY(24px)",
                  transition: "opacity .5s, transform .5s, border-color .3s",
                }}
              >
                <div style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
                  <Icon name={c.icon} size={18} style={{ color: "var(--accent)", marginTop: 2 }} />
                  <div>
                    <div style={{ fontSize: 19, fontWeight: 700 }}>{my ? c.my : c.en}</div>
                    <div style={{ fontSize: 13, color: "var(--text-secondary)", marginTop: 4 }}>{my ? c.myBody : c.enBody}</div>
                  </div>
                </div>
                <div style={{ marginTop: 14, padding: 12, borderRadius: 10, background: "var(--bg)", border: "1px solid var(--border)", fontSize: 12, color: "var(--text-secondary)" }}>
                  <Demo index={i} my={my} path={settings.downloadPath} />
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Supported sources */}
        <div style={{ paddingTop: 58, paddingBottom: 42 }}>
          <div style={{ display: "flex", gap: 8, alignItems: "center", fontSize: 18, fontWeight: 700, marginBottom: 14 }}><Icon name="library" size={18} /> {my ? "Sumber Disokong" : "Supported Sources"}</div>
          <p style={{ fontSize: 14, color: "var(--text-secondary)" }}>{my ? "Kod neutral ini menunjukkan keserasian luas tanpa mempromosikan mana-mana platform." : "These neutral codes signal broad compatibility without promoting any platform."}</p>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
            {SOURCES.map((s) => (
              <span key={s} style={{ fontSize: 12, fontWeight: 700, fontFamily: "monospace", padding: "7px 12px", borderRadius: 999, background: "var(--surface)", border: "1px solid var(--border)" }}>{s}</span>
            ))}
            <span style={{ fontSize: 12, fontWeight: 600, padding: "7px 12px", color: "var(--accent)" }}>{my ? "… dan banyak lagi" : "… and many more"}</span>
          </div>
        </div>

        {/* Use it well */}
        <div style={{ padding: 22, borderRadius: 16, background: "var(--accent-soft)", border: "1px solid var(--accent)" }}>
          <div style={{ display: "flex", gap: 8, alignItems: "center", fontSize: 18, fontWeight: 700, marginBottom: 12 }}><Icon name="heart" size={18} /> {my ? "Guna dengan betul" : "Use it well"}</div>
          <p style={{ fontSize: 14, color: "var(--text-secondary)", margin: 0, lineHeight: 1.6 }}>
            {my ? "Arkibkan kandungan milik anda atau yang memang anda berhak simpan—seperti muat naik sendiri, bahan awam atau Creative Commons, dan salinan yang dilesenkan untuk anda. Musim menyimpan fail terus ke peranti; anda memiliki dan mengawal simpanan itu." : "Archive content you own or are entitled to keep—your own uploads, public or Creative Commons material, and backups you are licensed for. Musim saves files directly to your device; you own and control that archive."}
          </p>
        </div>
      </div>
    </div>
  );
}

function Badge({ icon, label }: { icon: string; label: string }) {
  return (
    <span style={{ display: "inline-flex", gap: 6, alignItems: "center", fontSize: 12, fontWeight: 600, padding: "7px 10px", borderRadius: 999, background: "var(--surface)", border: "1px solid var(--border)", color: "var(--text-secondary)" }}>
      <Icon name={icon} size={12} /> {label}
    </span>
  );
}

function Demo({ index, my, path }: { index: number; my: boolean; path: string }) {
  switch (index) {
    case 2:
      return (
        <div style={{ display: "flex", gap: 9, alignItems: "center" }}>
          <Icon name="external" size={14} style={{ color: "var(--accent)" }} />
          <span style={{ flex: 1 }}>{my ? "Tampal pautan media…" : "Paste a media link…"}</span>
          <span style={{ fontSize: 11, fontWeight: 700, color: "#fff", padding: "6px 12px", borderRadius: 999, background: "var(--accent)" }}>{my ? "Simpan" : "Save"}</span>
        </div>
      );
    case 3:
      return <div>Video · 1080p · MP4 · 74 MB <Icon name="check" size={13} style={{ color: "var(--accent)", verticalAlign: "middle" }} /></div>;
    case 6:
      return <div style={{ display: "flex", gap: 8, alignItems: "center" }}><Icon name="folder" size={14} style={{ color: "var(--accent)" }} /><span style={{ fontFamily: "monospace", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{path}</span></div>;
    case 7:
      return (
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <div style={{ display: "flex", justifyContent: "space-between" }}><span>{my ? "Sedang menyimpan" : "Saving"}</span><span style={{ color: "var(--accent)" }}>68%</span></div>
          <div style={{ height: 6, background: "var(--border)", borderRadius: 999 }}><div style={{ width: "68%", height: "100%", borderRadius: 999, background: "linear-gradient(90deg,var(--accent),var(--accent2))" }} /></div>
        </div>
      );
    default:
      return <div style={{ opacity: 0.8 }}>{my ? "Pratonton dalam app" : "In-app preview"}</div>;
  }
}
