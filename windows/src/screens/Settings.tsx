import { useEffect, useState, type ReactNode } from "react";
import { open } from "@tauri-apps/plugin-dialog";
import { api, type AppAppearance, type ContainerOption, type HistoryLogFrequency, type MediaType, type QualityPreset } from "../api";
import { useApp } from "../lib/store";
import { GlassCard, Btn, Spinner } from "../ui/kit";
import { Icon } from "../ui/Icon";
import { ACCENTS, PATTERNS, patternLabel, type PatternStyle } from "../lib/theme";

const BROWSERS = ["none", "auto", "chrome", "edge", "firefox", "brave", "opera", "vivaldi", "chromium"];

export function Settings() {
  const { settings, updateSettings } = useApp();
  const my = settings.language === "malay";
  const [engine, setEngine] = useState<{ ytdlp: string | null; ffmpeg: boolean; ffprobe: boolean }>({ ytdlp: null, ffmpeg: false, ffprobe: false });
  const [installing, setInstalling] = useState(false);

  useEffect(() => { api.engineStatus().then(setEngine); }, []);

  async function installEngine() {
    setInstalling(true);
    try { await api.installEngine(); setEngine(await api.engineStatus()); }
    finally { setInstalling(false); }
  }
  async function pickFolder() {
    const picked = await open({ directory: true, defaultPath: settings.downloadPath });
    if (typeof picked === "string") updateSettings({ downloadPath: picked });
  }

  const quality = (id: QualityPreset) => ({ best: my ? "Terbaik" : "Best", good: my ? "Bagus (1080p)" : "Good (1080p)", normal: my ? "Biasa (720p)" : "Normal (720p)", low: my ? "Rendah (480p)" : "Low (480p)" }[id]);
  const container = (id: ContainerOption) => ({ auto: "Auto (MP4/MKV)", mp4: "MP4", mkv: "MKV", webm: "WEBM", original: my ? "Asal" : "Original" }[id]);

  return (
    <div style={{ height: "100%", overflow: "auto", padding: "40px 24px 40px" }}>
      <div style={{ maxWidth: 620, margin: "0 auto", display: "flex", flexDirection: "column", gap: 20 }}>
        <div>
          <div style={{ fontSize: 22, fontWeight: 800 }}>{my ? "Tetapan" : "Settings"}</div>
          <div style={{ color: "var(--text-secondary)" }}>{my ? "Tetapkan bagaimana Musim menyimpan dan menyusun media anda." : "Tune how Musim saves and organizes your media."}</div>
        </div>

        <Group title={my ? "Umum" : "General"} icon="info">
          <Row title={my ? "Nama Anda" : "Your Name"}>
            <input value={settings.userName} onChange={(e) => updateSettings({ userName: e.target.value })} style={{ width: 180 }} />
          </Row>
          <Row title={my ? "Bahasa" : "Language"}>
            <select value={settings.language} onChange={(e) => updateSettings({ language: e.target.value as "malay" | "english" })} style={{ width: 160 }}>
              <option value="malay">Bahasa Melayu</option>
              <option value="english">English</option>
            </select>
          </Row>
        </Group>

        <Group title={my ? "Pemberitahuan" : "Notifications"} icon="info">
          <Row title={my ? "Beritahu bila simpanan selesai" : "Notify when a save finishes"}>
            <Switch on={settings.notifyOnComplete} onChange={(v) => updateSettings({ notifyOnComplete: v })} />
          </Row>
        </Group>

        <Group title={my ? "Tema" : "Theme"} icon="image">
          <Row title={my ? "Rupa" : "Appearance"}>
            <div className="segmented">
              {(["system", "light", "dark"] as AppAppearance[]).map((a) => (
                <button key={a} className={settings.appearance === a ? "seg-active" : ""} onClick={() => updateSettings({ appearance: a })}>
                  {a === "system" ? (my ? "Sistem" : "System") : a === "light" ? (my ? "Cerah" : "Light") : my ? "Gelap" : "Dark"}
                </button>
              ))}
            </div>
          </Row>
          <Row title={my ? "Warna Aksen" : "Accent Color"} sub={my ? "Palet berinspirasikan Malaysia" : "Malaysian-inspired palette"}>
            <div style={{ display: "flex", gap: 8 }}>
              {ACCENTS.map((a) => (
                <button key={a.id} title={a.name} onClick={() => updateSettings({ accent: a.id })} style={{ width: 22, height: 22, borderRadius: 999, background: a.hex, border: settings.accent === a.id ? "2px solid var(--text-primary)" : "2px solid transparent", display: "grid", placeItems: "center" }}>
                  {settings.accent === a.id && <Icon name="check" size={10} style={{ color: "#fff" }} />}
                </button>
              ))}
            </div>
          </Row>
          <Row title={my ? "Corak" : "Pattern"} sub={my ? "Motif halus pada panel" : "Subtle motif on panels"}>
            <select value={settings.pattern} onChange={(e) => updateSettings({ pattern: e.target.value })} style={{ width: 150 }}>
              {PATTERNS.map((p) => <option key={p} value={p}>{patternLabel(p as PatternStyle, my)}</option>)}
            </select>
          </Row>
        </Group>

        <Group title={my ? "Arkib" : "Archive"} icon="archive">
          <Row title={my ? "Simpan media di" : "Save media to"} info={my ? "Ini juga folder Pustaka." : "This is also your Library folder."}>
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <span style={{ fontSize: 12, color: "var(--text-secondary)", maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{settings.downloadPath}</span>
              <Btn onClick={pickFolder}>{my ? "Pilih…" : "Choose…"}</Btn>
            </div>
          </Row>
          <Row title={my ? "Simpan sejarah arkib" : "Log archive history"} sub={my ? "Fail teks laporan dalam folder Laporan" : "Report text files in the Report folder"}>
            <select value={settings.historyLog} onChange={(e) => updateSettings({ historyLog: e.target.value as HistoryLogFrequency })} style={{ width: 150 }}>
              <option value="never">{my ? "Jangan simpan fail" : "Don't save a file"}</option>
              <option value="daily">{my ? "Harian" : "Daily"}</option>
              <option value="weekly">{my ? "Mingguan" : "Weekly"}</option>
              <option value="monthly">{my ? "Bulanan" : "Monthly"}</option>
            </select>
          </Row>
          <Row title={my ? "Simpanan serentak" : "Concurrent saves"}>
            <Stepper value={settings.maxConcurrentDownloads} min={1} max={10} onChange={(v) => updateSettings({ maxConcurrentDownloads: v })} />
          </Row>
          <Row title={my ? "Jenis lalai" : "Default type"}>
            <select value={settings.oneClickType} onChange={(e) => updateSettings({ oneClickType: e.target.value as MediaType })} style={{ width: 120 }}>
              <option value="video">Video</option>
              <option value="audio">Audio</option>
            </select>
          </Row>
          <Row title={my ? "Kualiti lalai" : "Default quality"}>
            <select value={settings.oneClickQuality} onChange={(e) => updateSettings({ oneClickQuality: e.target.value as QualityPreset })} style={{ width: 160 }}>
              {(["best", "good", "normal", "low"] as QualityPreset[]).map((q) => <option key={q} value={q}>{quality(q)}</option>)}
            </select>
          </Row>
          <Row title={my ? "Bekas output" : "Output container"}>
            <select value={settings.container} onChange={(e) => updateSettings({ container: e.target.value as ContainerOption })} style={{ width: 160 }}>
              {(["auto", "mp4", "mkv", "webm", "original"] as ContainerOption[]).map((c) => <option key={c} value={c}>{container(c)}</option>)}
            </select>
          </Row>
          <Row title={my ? "Susun ikut platform" : "Organize by platform"}>
            <Switch on={settings.organizeByPlatform} onChange={(v) => updateSettings({ organizeByPlatform: v })} />
          </Row>
          <Row title={my ? "Subfolder pencipta" : "Creator subfolders"}>
            <Switch on={settings.channelSubfolders} onChange={(v) => updateSettings({ channelSubfolders: v })} />
          </Row>
        </Group>

        <Group title={my ? "Penamaan" : "Naming"} icon="edit">
          <Row title={my ? "Namakan fail dari tajuk video" : "Auto-name files from video title"}>
            <Switch on={settings.autoNaming} onChange={(v) => updateSettings({ autoNaming: v })} />
          </Row>
          <Row title={my ? "Penamaan lanjutan" : "Advanced naming"} sub={my ? "Awalan, tarikh, nombor & akhiran" : "Prefix, date, counter & suffix"}>
            <Switch on={settings.advancedNaming} disabled={!settings.autoNaming} onChange={(v) => updateSettings({ advancedNaming: v })} />
          </Row>
          {settings.autoNaming && settings.advancedNaming ? (
            <>
              <Row title={my ? "Awalan / Akhiran" : "Prefix / Suffix"}>
                <div style={{ display: "flex", gap: 6 }}>
                  <input placeholder={my ? "Awalan" : "Prefix"} value={settings.namePrefix} onChange={(e) => updateSettings({ namePrefix: e.target.value })} style={{ width: 96 }} />
                  <input placeholder={my ? "Akhiran" : "Suffix"} value={settings.nameSuffix} onChange={(e) => updateSettings({ nameSuffix: e.target.value })} style={{ width: 96 }} />
                </div>
              </Row>
              <Row title={my ? "Pemisah" : "Separator"}>
                <select value={settings.nameSeparator} onChange={(e) => updateSettings({ nameSeparator: e.target.value })} style={{ width: 160 }}>
                  <option value=" - ">{my ? "- (Sengkang)" : "- (Hyphen)"}</option>
                  <option value="_">{my ? "_ (Garis bawah)" : "_ (Underscore)"}</option>
                  <option value=" ">{my ? "Ruang" : "Space"}</option>
                </select>
              </Row>
              <Row title={my ? "Tarikh" : "Date"}>
                <select value={settings.nameDate} onChange={(e) => updateSettings({ nameDate: e.target.value })} style={{ width: 160 }}>
                  <option value="none">{my ? "Tiada" : "None"}</option>
                  <option value="%Y%m%d">YYYYMMDD</option>
                  <option value="%Y-%m-%d">YYYY-MM-DD</option>
                </select>
              </Row>
              <Row title={my ? "Nombor turutan" : "Start number"}>
                <Switch on={settings.nameCounter} onChange={(v) => updateSettings({ nameCounter: v })} />
              </Row>
              <div style={{ padding: "0 14px 8px", fontSize: 11, color: "var(--text-secondary)" }}>
                {my ? "Contoh:" : "Example:"} <span style={{ fontFamily: "monospace", color: "var(--accent)" }}>{namingExample(settings.namePrefix, settings.nameDate, settings.nameCounter, settings.nameSuffix, settings.nameSeparator)}</span>
              </div>
            </>
          ) : (
            <Row title={my ? "Templat nama fail" : "Filename template"} sub={my ? "Templat output yt-dlp" : "yt-dlp output template"}>
              <input value={settings.filenameTemplate} disabled={!settings.autoNaming} onChange={(e) => updateSettings({ filenameTemplate: e.target.value })} style={{ width: 220, fontFamily: "monospace", fontSize: 12 }} />
            </Row>
          )}
        </Group>

        <Group title={my ? "Rangkaian & Kuki" : "Network & Cookies"} icon="settings">
          <Row title={my ? "Kuki pelayar" : "Browser cookies"} sub={my ? "Untuk video peribadi / perlu log masuk" : "For private / login-required videos"}>
            <select value={settings.browserForCookies} onChange={(e) => updateSettings({ browserForCookies: e.target.value })} style={{ width: 150 }}>
              {BROWSERS.map((b) => <option key={b} value={b}>{b === "none" ? (my ? "Dimatikan" : "Off") : b === "auto" ? (my ? "Pelayar lalai" : "Default browser") : b.charAt(0).toUpperCase() + b.slice(1)}</option>)}
            </select>
          </Row>
          <Row title={my ? "Proksi" : "Proxy"} sub="e.g. socks5://127.0.0.1:1080">
            <input placeholder={my ? "Pilihan" : "Optional"} value={settings.proxy} onChange={(e) => updateSettings({ proxy: e.target.value })} style={{ width: 220 }} />
          </Row>
        </Group>

        <Group title={my ? "Sematan" : "Embedding"} icon="download">
          <Row title={my ? "Semat sari kata" : "Embed subtitles"}><Switch on={settings.embedSubs} onChange={(v) => updateSettings({ embedSubs: v })} /></Row>
          <Row title={my ? "Semat lakaran kecil" : "Embed thumbnail"}><Switch on={settings.embedThumbnail} onChange={(v) => updateSettings({ embedThumbnail: v })} /></Row>
          <Row title={my ? "Semat metadata" : "Embed metadata"}><Switch on={settings.embedMetadata} onChange={(v) => updateSettings({ embedMetadata: v })} /></Row>
          <Row title={my ? "Semat bab" : "Embed chapters"}><Switch on={settings.embedChapters} onChange={(v) => updateSettings({ embedChapters: v })} /></Row>
        </Group>

        <Group title={my ? "Enjin" : "Engine"} icon="settings">
          <Row title={my ? "Kemas kini automatik" : "Auto-update engine"} sub={my ? "Semak kemas kini yt-dlp semasa app dibuka" : "Check & update yt-dlp on launch"}>
            <Switch on={settings.autoUpdateEngine} onChange={(v) => updateSettings({ autoUpdateEngine: v })} />
          </Row>
          <Row title="yt-dlp" sub={engine.ytdlp ?? (my ? "Belum dipasang" : "Not installed")}>
            {installing ? <Spinner size={16} /> : <Btn onClick={installEngine}>{engine.ytdlp ? (my ? "Semak kemas kini" : "Check for updates") : my ? "Pasang" : "Install"}</Btn>}
          </Row>
          <Row title="ffmpeg" sub={engine.ffmpeg ? (my ? "Sedia" : "Ready") : my ? "Tidak ditemui" : "Not found"}>
            <Icon name={engine.ffmpeg ? "check" : "info"} size={16} style={{ color: engine.ffmpeg ? "#4ade80" : "#fb923c" }} />
          </Row>
        </Group>
      </div>
    </div>
  );
}

function Group({ title, icon, children }: { title: string; icon: string; children: ReactNode }) {
  return (
    <div>
      <div style={{ display: "flex", gap: 8, alignItems: "center", marginBottom: 10 }}>
        <Icon name={icon} size={16} style={{ color: "var(--accent)" }} />
        <span style={{ fontSize: 15, fontWeight: 700 }}>{title}</span>
      </div>
      <GlassCard radius={12} style={{ padding: "4px 0" }}>{children}</GlassCard>
    </div>
  );
}

function Row({ title, sub, info, children }: { title: string; sub?: string; info?: string; children: ReactNode }) {
  return (
    <div style={{ display: "flex", alignItems: "center", padding: "9px 14px", gap: 12 }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", gap: 5, alignItems: "center" }}>
          <span style={{ fontSize: 14 }}>{title}</span>
          {info && <span title={info} style={{ color: "var(--text-secondary)", display: "inline-flex" }}><Icon name="info" size={11} /></span>}
        </div>
        {sub && <div style={{ fontSize: 11, color: "var(--text-secondary)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{sub}</div>}
      </div>
      {children}
    </div>
  );
}

export function Switch({ on, onChange, disabled }: { on: boolean; onChange: (v: boolean) => void; disabled?: boolean }) {
  return (
    <button className={`switch ${on ? "on" : ""}`} disabled={disabled} onClick={() => onChange(!on)}>
      <span className="knob" />
    </button>
  );
}

function Stepper({ value, min, max, onChange }: { value: number; min: number; max: number; onChange: (v: number) => void }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
      <button className="icon-btn" style={{ width: 26, height: 26, background: "var(--surface-hover)", fontSize: 16, fontWeight: 700 }} onClick={() => onChange(Math.max(min, value - 1))}>−</button>
      <span style={{ minWidth: 20, textAlign: "center", fontVariantNumeric: "tabular-nums" }}>{value}</span>
      <button className="icon-btn" style={{ width: 26, height: 26, background: "var(--surface-hover)" }} onClick={() => onChange(Math.min(max, value + 1))}><Icon name="plus" size={12} /></button>
    </div>
  );
}

function namingExample(prefix: string, date: string, counter: boolean, suffix: string, sep: string): string {
  const parts: string[] = [];
  if (prefix) parts.push(prefix);
  parts.push("Video Title");
  if (date !== "none") parts.push(date === "%Y-%m-%d" ? "2026-07-16" : "20260716");
  if (counter) parts.push("001");
  if (suffix) parts.push(suffix);
  return parts.join(sep) + ".mp4";
}
