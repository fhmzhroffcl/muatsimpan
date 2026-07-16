import * as React from "react";
import { useState, type ReactNode } from "react";
import { open } from "@tauri-apps/plugin-dialog";
import { api, type QualityPreset } from "../api";
import { useApp } from "../lib/store";
import { Logo, GlassCard, Btn, Icon } from "../ui/kit";

const QUALITIES: { id: QualityPreset; my: string; en: string }[] = [
  { id: "best", my: "Terbaik", en: "Best" },
  { id: "good", my: "Bagus (1080p)", en: "Good (1080p)" },
  { id: "normal", my: "Biasa (720p)", en: "Normal (720p)" },
  { id: "low", my: "Rendah (480p)", en: "Low (480p)" },
];

const BROWSERS = ["none", "auto", "chrome", "edge", "firefox", "brave", "opera", "vivaldi", "chromium"];
const PLATFORM_FOLDERS = ["YouTube", "TikTok", "Facebook", "Instagram"];
const STEPS = 7;

export function Onboarding() {
  const { settings, updateSettings } = useApp();
  const my = settings.language === "malay";
  const [step, setStep] = useState(0);
  const [name, setName] = useState(settings.userName);
  const [note, setNote] = useState(
    "Idea pertama: simpan video rujukan dalam folder platform, kemudian tambah nota kecil supaya senang jumpa balik."
  );

  const trimmedName = name.trim();
  const trimmedNote = note.trim();
  const continueDisabled = (step === 2 && !trimmedName) || (step === 5 && !trimmedNote);

  async function finish() {
    if (step >= 2) updateSettings({ userName: trimmedName });
    if (trimmedNote) {
      const root = settings.downloadPath;
      const sep = root.includes("\\") ? "\\" : "/";
      const folder = `${root}${sep}YouTube`;
      await api.libraryNewFolder(root, "YouTube").catch(() => {});
      await api.upsertNote(folder, {
        id: crypto.randomUUID(),
        text: trimmedNote,
        color: "yellow",
        size: "wide",
      }).catch(() => {});
    }
    updateSettings({ onboardingCompleted: true });
  }

  function advance() {
    if (step === 2) updateSettings({ userName: trimmedName });
    if (step === STEPS - 1) finish();
    else setStep((s) => s + 1);
  }

  async function pickFolder() {
    const picked = await open({ directory: true, defaultPath: settings.downloadPath });
    if (typeof picked === "string") updateSettings({ downloadPath: picked });
  }

  const folderName = settings.downloadPath.split(/[\\/]/).filter(Boolean).pop() ?? "Musim";

  return (
    <div style={{ position: "fixed", inset: 0, background: "var(--bg)", display: "flex", flexDirection: "column", padding: "0 60px" }}>
      <div style={{ flex: 1, display: "grid", placeItems: "center" }}>
        <div key={step} className="fade-in" style={{ width: "100%", maxWidth: 620 }}>
          {step === 0 && (
            <Center>
              <Logo size={76} />
              <h1 style={h1}>{my ? "Pilih Bahasa" : "Choose Language"}</h1>
              <p style={sub}>{my ? "Pilih bahasa untuk Musim. Anda boleh tukar kemudian di Tetapan." : "Choose the language for Musim. You can change this later in Settings."}</p>
              <div className="segmented" style={{ marginTop: 8 }}>
                {(["malay", "english"] as const).map((l) => (
                  <button key={l} className={settings.language === l ? "seg-active" : ""} onClick={() => updateSettings({ language: l })}>
                    {l === "malay" ? "Bahasa Melayu" : "English"}
                  </button>
                ))}
              </div>
            </Center>
          )}

          {step === 1 && (
            <Center>
              <Logo size={76} />
              <h1 style={h1}>{my ? "Selamat Datang ke Musim" : "Welcome to Musim"}</h1>
              <p style={{ ...sub, fontSize: 18 }}>
                {my
                  ? "Arkib + Simpan. Tampal pautan video atau audio, pilih kualiti, dan biar Musim susun fail anda dengan kemas."
                  : "Archive + Save. Paste video or audio links, pick quality, and let Musim organize your files neatly."}
              </p>
            </Center>
          )}

          {step === 2 && (
            <Center>
              <Icon name="heart" size={44} style={{ color: "var(--accent)" }} />
              <h1 style={h1}>{my ? "Apa nama anda?" : "What should we call you?"}</h1>
              <input
                autoFocus
                value={name}
                onChange={(e) => setName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && trimmedName && advance()}
                placeholder={my ? "Nama anda" : "Your name"}
                style={{ fontSize: 20, textAlign: "center", padding: 14, width: 320 }}
              />
            </Center>
          )}

          {step === 3 && (
            <div>
              <h1 style={h1left}>{my ? "Tetapan Asas" : "The essentials"}</h1>
              <p style={sub}>{my ? "Musim akan cipta folder YouTube, TikTok, Facebook dan Instagram secara automatik." : "Musim will create YouTube, TikTok, Facebook and Instagram folders automatically."}</p>
              <GlassCard radius={16} style={{ padding: 18, marginTop: 16, display: "flex", flexDirection: "column", gap: 14 }}>
                <Row icon="folder" title={my ? "Simpan media di" : "Save media to"}>
                  <Btn icon="chevronDown" onClick={pickFolder}>{folderName}</Btn>
                </Row>
                <Row icon="library" title={my ? "Susun ikut platform" : "Organize by platform"} sub={my ? "Sumber baharu akan dapat folder sendiri." : "New sources get their own folder."}>
                  <Toggle on={settings.organizeByPlatform} onChange={(v) => updateSettings({ organizeByPlatform: v })} />
                </Row>
                <Row icon="library" title={my ? "Subfolder pencipta" : "Creator subfolders"} sub={my ? "Folder pencipta duduk di dalam folder platform." : "Creator folders sit inside the platform folder."}>
                  <Toggle on={settings.channelSubfolders} onChange={(v) => updateSettings({ channelSubfolders: v })} />
                </Row>
                <div style={{ background: "rgba(255,255,255,.04)", borderRadius: 14, padding: 12 }}>
                  <div style={{ fontSize: 12, fontWeight: 600, color: "var(--text-secondary)", marginBottom: 8 }}>{my ? "Struktur folder" : "Folder structure"}</div>
                  <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                    {PLATFORM_FOLDERS.map((f) => (
                      <span key={f} style={{ display: "inline-flex", gap: 5, alignItems: "center", fontSize: 12, fontWeight: 600, padding: "6px 10px", borderRadius: 999, background: "var(--accent-soft)" }}>
                        <Icon name="folder" size={13} /> {f}
                      </span>
                    ))}
                  </div>
                  <div style={{ fontFamily: "monospace", fontSize: 12, color: "var(--accent)", marginTop: 8 }}>
                    {my ? "Contoh: YouTube / Nama Pencipta / Tajuk Video.mp4" : "Example: YouTube / Creator Name / Video Title.mp4"}
                  </div>
                </div>
                <Row icon="settings" title={my ? "Kuki pelayar" : "Browser cookies"} sub={my ? "Pilihan untuk video peribadi." : "Optional for private videos."}>
                  <select value={settings.browserForCookies} onChange={(e) => updateSettings({ browserForCookies: e.target.value })} style={{ width: 150 }}>
                    {BROWSERS.map((b) => <option key={b} value={b}>{browserLabel(b, my)}</option>)}
                  </select>
                </Row>
                <Row icon="film" title={my ? "Kualiti lalai" : "Default quality"}>
                  <select value={settings.oneClickQuality} onChange={(e) => updateSettings({ oneClickQuality: e.target.value as QualityPreset })} style={{ width: 170 }}>
                    {QUALITIES.map((q) => <option key={q.id} value={q.id}>{my ? q.my : q.en}</option>)}
                  </select>
                </Row>
              </GlassCard>
            </div>
          )}

          {step === 4 && (
            <div>
              <h1 style={h1left}>{my ? "Penamaan Fail" : "File naming"}</h1>
              <p style={sub}>{my ? "Gunakan tajuk video, atau bina nama fail dengan awalan, tarikh, nombor dan akhiran." : "Use video titles, or compose filenames with prefix, date, counter and suffix."}</p>
              <GlassCard radius={16} style={{ padding: 18, marginTop: 16, display: "flex", flexDirection: "column", gap: 14 }}>
                <Row icon="edit" title={my ? "Namakan fail dari tajuk video" : "Auto-name files from video title"}>
                  <Toggle on={settings.autoNaming} onChange={(v) => updateSettings({ autoNaming: v })} />
                </Row>
                <Row icon="edit" title={my ? "Penamaan lanjutan" : "Advanced naming"} sub={my ? "Awalan, tarikh, nombor dan akhiran." : "Prefix, date, counter and suffix."}>
                  <Toggle on={settings.advancedNaming} disabled={!settings.autoNaming} onChange={(v) => updateSettings({ advancedNaming: v })} />
                </Row>
                <div style={{ display: "flex", gap: 8 }}>
                  <input placeholder={my ? "Awalan" : "Prefix"} value={settings.namePrefix} disabled={!settings.autoNaming || !settings.advancedNaming} onChange={(e) => updateSettings({ namePrefix: e.target.value })} style={{ flex: 1 }} />
                  <input placeholder={my ? "Akhiran" : "Suffix"} value={settings.nameSuffix} disabled={!settings.autoNaming || !settings.advancedNaming} onChange={(e) => updateSettings({ nameSuffix: e.target.value })} style={{ flex: 1 }} />
                </div>
                <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                  <select value={settings.nameDate} disabled={!settings.autoNaming || !settings.advancedNaming} onChange={(e) => updateSettings({ nameDate: e.target.value })} style={{ width: 190 }}>
                    <option value="none">{my ? "Tiada" : "None"}</option>
                    <option value="%Y%m%d">YYYYMMDD</option>
                    <option value="%Y-%m-%d">YYYY-MM-DD</option>
                  </select>
                  <label style={{ display: "flex", gap: 6, alignItems: "center", fontSize: 13 }}>
                    <input type="checkbox" checked={settings.nameCounter} disabled={!settings.autoNaming || !settings.advancedNaming} onChange={(e) => updateSettings({ nameCounter: e.target.checked })} style={{ width: "auto" }} />
                    {my ? "Nombor turutan" : "Counter"}
                  </label>
                </div>
              </GlassCard>
            </div>
          )}

          {step === 5 && (
            <div>
              <h1 style={h1left}>{my ? "Nota Pertama" : "First note"}</h1>
              <p style={sub}>{my ? "Tulis satu nota contoh. Musim akan simpan dalam Pustaka." : "Write one sample note. Musim saves it in the Library."}</p>
              <GlassCard radius={16} style={{ padding: 18, marginTop: 16, display: "flex", gap: 12 }}>
                <div style={{ width: 190, height: 132, background: "rgba(240,200,60,.9)", borderRadius: 14, padding: 14, transform: "rotate(-1.5deg)", boxShadow: "0 8px 16px rgba(0,0,0,.18)", color: "rgba(0,0,0,.72)", fontWeight: 600, fontSize: 13, overflow: "hidden" }}>
                  {trimmedNote || (my ? "Nota contoh..." : "Sample note...")}
                </div>
                <textarea value={note} onChange={(e) => setNote(e.target.value)} style={{ flex: 1, height: 132, resize: "none" }} />
              </GlassCard>
            </div>
          )}

          {step === 6 && (
            <Center>
              <Icon name="heart" size={40} style={{ color: "var(--accent)" }} />
              <h1 style={h1}>{my ? "Sokong Musim" : "Support Musim"}</h1>
              <p style={sub}>{my ? "Imbas QR DuitNow jika anda mahu sokong pembangunan app ini. Boleh juga langkau dulu." : "Scan the DuitNow QR if you want to support the app. You can skip this for now."}</p>
              <DuitNowQR />
            </Center>
          )}
        </div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 24, alignItems: "center", paddingBottom: 44 }}>
        <div style={{ display: "flex", gap: 8 }}>
          {Array.from({ length: STEPS }).map((_, i) => (
            <span key={i} style={{ width: i === step ? 26 : 8, height: 8, borderRadius: 999, background: i === step ? "var(--accent)" : "rgba(150,150,150,.3)", transition: "all .3s" }} />
          ))}
        </div>
        <div style={{ display: "flex", width: "100%", maxWidth: 620, alignItems: "center" }}>
          {step > 0 && <button className="btn-glass" style={{ border: "none", background: "transparent", color: "var(--text-secondary)" }} onClick={() => setStep((s) => s - 1)}>{my ? "Kembali" : "Back"}</button>}
          <div style={{ flex: 1 }} />
          {step === STEPS - 1 && <Btn onClick={finish} style={{ marginRight: 8 }}>{my ? "Langkau" : "Skip"}</Btn>}
          <Btn variant="primary" onClick={advance} disabled={continueDisabled}>
            {step === STEPS - 1 ? (my ? "Mula Guna Musim" : "Start Musim") : my ? "Teruskan" : "Continue"}
          </Btn>
        </div>
      </div>
    </div>
  );
}

function Center({ children }: { children: ReactNode }) {
  return <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 16, textAlign: "center" }}>{children}</div>;
}
function Row({ icon, title, sub, children }: { icon: string; title: string; sub?: string; children: ReactNode }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
      <span style={{ color: "var(--accent)", width: 28, display: "grid", placeItems: "center" }}><Icon name={icon} size={18} /></span>
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 500 }}>{title}</div>
        {sub && <div style={{ fontSize: 12, color: "var(--text-secondary)" }}>{sub}</div>}
      </div>
      {children}
    </div>
  );
}
function Toggle({ on, onChange, disabled }: { on: boolean; onChange: (v: boolean) => void; disabled?: boolean }) {
  return (
    <button
      onClick={() => !disabled && onChange(!on)}
      style={{
        width: 42, height: 24, borderRadius: 999, border: "none", position: "relative",
        background: on ? "linear-gradient(135deg,var(--accent),var(--accent2))" : "var(--border-strong)",
        opacity: disabled ? 0.4 : 1, transition: "background .2s",
      }}
    >
      <span style={{ position: "absolute", top: 3, left: on ? 21 : 3, width: 18, height: 18, borderRadius: 999, background: "#fff", transition: "left .2s" }} />
    </button>
  );
}
function DuitNowQR() {
  return (
    <img src={new URL("../assets/duitnow.png", import.meta.url).href} alt="DuitNow" style={{ width: 230, height: 230, objectFit: "contain", borderRadius: 14, background: "#fff", padding: 8 }} />
  );
}
function browserLabel(b: string, my: boolean) {
  if (b === "none") return my ? "Dimatikan" : "Off";
  if (b === "auto") return my ? "Pelayar lalai" : "Default browser";
  return b.charAt(0).toUpperCase() + b.slice(1);
}

const h1: React.CSSProperties = { fontSize: 30, fontWeight: 800, margin: 0 };
const h1left: React.CSSProperties = { fontSize: 28, fontWeight: 800, margin: 0 };
const sub: React.CSSProperties = { color: "var(--text-secondary)", fontSize: 15, margin: "6px 0 0", lineHeight: 1.5 };
