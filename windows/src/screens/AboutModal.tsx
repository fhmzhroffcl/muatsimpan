import { useState } from "react";
import privacyMd from "../assets/legal/PRIVACY.md?raw";
import termsMd from "../assets/legal/TERMS.md?raw";
import noticeMd from "../assets/legal/NOTICE.md?raw";
import duitnowUrl from "../assets/duitnow.png";
import { useApp } from "../lib/store";
import { Modal, Logo, Btn, Segmented } from "../ui/kit";
import { Markdown } from "../ui/Markdown";

const TECH = ["Deno", "yt-dlp", "FFmpeg", "Claude Fable 5", "Claude Opus 4.8", "ChatGPT 5.5", "Gemini 3.5 Flash", "Tauri", "Rust", "React", "TypeScript"];

type Tab = "about" | "changelog" | "privacy" | "terms" | "licenses";

export function AboutModal({ onClose }: { onClose: () => void }) {
  const { settings } = useApp();
  const my = settings.language === "malay";
  const [tab, setTab] = useState<Tab>("about");
  const [showQR, setShowQR] = useState(false);

  const bodyText = my
    ? "MUSIM (Arkib + Simpan) v2.0 ialah arkib media peribadi natif yang ringkas, bebas iklan, dan dikuasakan oleh seni bina sumber terbuka VidBee (Deno, yt-dlp, FFmpeg).\n\nDireka untuk menyimpan media dengan pantas daripada pelbagai sumber, ia turut dilengkapi dengan pustaka fail, pemain video terbina dalam, dan editor video. Aplikasi ini dihasilkan secara kolaboratif bersama Claude Fable 5 & Opus 4.8 oleh Fahim Zahar."
    : "MUSIM (Arkib + Simpan) v2.0 is a lightweight, ad-free, native personal media archive powered by the open-source VidBee architecture (Deno, yt-dlp, FFmpeg).\n\nBuilt for fast local saves from many media sources, it includes a built-in player and a two-panel video editor. This app was created collaboratively with Claude Fable 5 & Opus 4.8 by Fahim Zahar.";

  const tabLabel = (t: Tab) => {
    const m: Record<Tab, [string, string]> = {
      about: ["Perihal", "About"], changelog: ["Perubahan", "Changelog"],
      privacy: ["Privasi", "Privacy"], terms: ["Terma", "Terms"], licenses: ["Lesen", "Licenses"],
    };
    return my ? m[t][0] : m[t][1];
  };

  if (showQR) {
    return (
      <Modal onClose={onClose} width={520}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 18 }}>
          <h2 style={{ margin: 0, fontSize: 20 }}>{my ? "Sokong Saya" : "Support Me"}</h2>
          <p style={{ margin: 0, color: "var(--text-secondary)", fontSize: 12 }}>{my ? "Terima kasih atas sokongan anda 🤍" : "Thank you for your support 🤍"}</p>
          <img src={duitnowUrl} alt="DuitNow" style={{ width: 260, height: 260, objectFit: "contain", background: "#fff", borderRadius: 14, padding: 8 }} />
          <p style={{ margin: 0, fontSize: 12, color: "var(--text-secondary)" }}>{my ? "Imbas dengan mana-mana aplikasi bank · DuitNow" : "Scan with any Malaysian banking app · DuitNow"}</p>
          <Btn icon="chevronLeft" onClick={() => setShowQR(false)}>{my ? "Kembali" : "Back"}</Btn>
        </div>
      </Modal>
    );
  }

  return (
    <Modal onClose={onClose} width={520}>
      <div style={{ display: "flex", flexDirection: "column", gap: 18, alignItems: "center" }}>
        <Segmented<Tab>
          value={tab}
          onChange={setTab}
          options={(["about", "changelog", "privacy", "terms", "licenses"] as Tab[]).map((t) => ({ id: t, label: tabLabel(t) }))}
        />

        {tab === "about" && (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 16 }}>
            <Logo size={74} />
            <div style={{ textAlign: "center" }}>
              <div style={{ fontSize: 23, fontWeight: 800 }}>MUSIM</div>
              <div style={{ color: "var(--text-secondary)", letterSpacing: 2 }}>Arkib + Simpan</div>
            </div>
            <p style={{ margin: 0, textAlign: "justify", fontSize: 13.5, color: "var(--text-secondary)", lineHeight: 1.6, whiteSpace: "pre-wrap" }}>{bodyText}</p>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 7, justifyContent: "center" }}>
              {TECH.map((t) => (
                <span key={t} style={{ fontSize: 11, fontWeight: 600, padding: "5px 10px", borderRadius: 999, background: "var(--surface-hover)", border: "1px solid var(--border)", color: "var(--text-secondary)" }}>{t}</span>
              ))}
            </div>
            <div style={{ display: "flex", gap: 10 }}>
              <Btn variant="primary" icon="heart" onClick={() => setShowQR(true)}>{my ? "Sokong Saya" : "Support Me"}</Btn>
              <Btn onClick={onClose}>{my ? "Tutup" : "Done"}</Btn>
            </div>
          </div>
        )}

        {tab === "changelog" && (
          <div style={{ width: 440, maxHeight: 360, overflow: "auto", display: "flex", flexDirection: "column", gap: 18 }}>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{my ? "Perubahan versi" : "Version history"}</div>
            <ChangelogEntry version="2.0" date="15 Jul 2026" title={my ? "Pemain & editor dibetulkan" : "Player & editor fixed"} body={my ? "Tambah pemain video terbina dalam dan susun atur editor dua panel dengan garis masa di bawah video." : "Added the built-in video player and a two-panel editor with the timeline below the video."} />
            <ChangelogEntry version="1.0" date="10 Jul 2026" title={my ? "Keluaran pertama" : "First release"} body={my ? "Simpan media video dan audio, pustaka fail, folder, nota lekat, serta tetapan penamaan fail." : "Saved video and audio media, file library, folders, sticky notes, and filename settings."} />
          </div>
        )}

        {tab === "privacy" && <LegalDoc text={privacyMd} />}
        {tab === "terms" && <LegalDoc text={termsMd} />}
        {tab === "licenses" && <LegalDoc text={noticeMd} />}

        {tab !== "about" && <Btn onClick={onClose}>{my ? "Tutup" : "Done"}</Btn>}
      </div>
    </Modal>
  );
}

function ChangelogEntry({ version, date, title, body }: { version: string; date: string; title: string; body: string }) {
  return (
    <div style={{ padding: 14, borderRadius: 12, background: "rgba(128,128,128,.08)", border: "1px solid var(--border)" }}>
      <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
        <span style={{ fontWeight: 700, color: "var(--accent)" }}>v{version}</span>
        <span style={{ fontSize: 12, color: "var(--text-secondary)" }}>{date}</span>
      </div>
      <div style={{ fontSize: 15, fontWeight: 600, margin: "6px 0 4px" }}>{title}</div>
      <div style={{ fontSize: 13, color: "var(--text-secondary)" }}>{body}</div>
    </div>
  );
}

function LegalDoc({ text }: { text: string }) {
  return (
    <div style={{ width: 464, height: 360, overflow: "auto", background: "var(--surface)", borderRadius: 12, border: "1px solid var(--border)", padding: 14 }}>
      <Markdown text={text} />
    </div>
  );
}
