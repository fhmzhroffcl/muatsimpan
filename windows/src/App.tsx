import { useEffect, useState, type ReactNode } from "react";
import {
  api,
  onDownloadsUpdated,
  type AppSettings,
  type DownloadItem,
  type MediaType,
} from "./api";

// Phase 1 shell: this is a functional harness that exercises the full Rust
// engine (settings, yt-dlp install, enqueue, live progress). The complete
// three-column UI, splash, onboarding, library and editor land in later phases.

function applyTheme(settings: AppSettings) {
  const root = document.documentElement;
  root.dataset.accent = settings.accent;
  const theme =
    settings.appearance === "system"
      ? window.matchMedia("(prefers-color-scheme: light)").matches
        ? "light"
        : "dark"
      : settings.appearance;
  root.dataset.theme = theme;
}

export default function App() {
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [ready, setReady] = useState(false);
  const [installing, setInstalling] = useState(false);
  const [text, setText] = useState("");
  const [mediaType, setMediaType] = useState<MediaType>("video");
  const [items, setItems] = useState<DownloadItem[]>([]);

  useEffect(() => {
    api.getSettings().then((s) => {
      setSettings(s);
      applyTheme(s);
    });
    api.engineReady().then(setReady);
    api.getDownloads().then(setItems);
    const un = onDownloadsUpdated(setItems);
    return () => {
      un.then((f) => f());
    };
  }, []);

  async function install() {
    setInstalling(true);
    try {
      await api.installEngine();
      setReady(await api.engineReady());
    } finally {
      setInstalling(false);
    }
  }

  async function save() {
    const urls = await api.extractLinks(text);
    if (urls.length === 0) return;
    await api.enqueueUrls(urls, mediaType);
    setText("");
  }

  const active = items.filter((i) =>
    ["pending", "downloading", "processing"].includes(i.status)
  );
  const history = items.filter((i) =>
    ["completed", "error", "cancelled"].includes(i.status)
  );

  return (
    <div style={{ padding: 28, height: "100%", overflow: "auto" }}>
      <header style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 24 }}>
        <div
          className="accent-gradient"
          style={{ width: 40, height: 40, borderRadius: 10 }}
        />
        <div>
          <h1 style={{ margin: 0, fontSize: 22 }}>Musim</h1>
          <div style={{ color: "var(--text-secondary)", fontSize: 13 }}>
            Muat + Simpan — Windows
          </div>
        </div>
      </header>

      {!ready && (
        <div className="glass-card" style={{ padding: 16, marginBottom: 20 }}>
          <div style={{ marginBottom: 10 }}>
            The download engine (yt-dlp) isn't available yet.
          </div>
          <button className="btn-primary" onClick={install} disabled={installing}>
            {installing ? "Installing…" : "Install engine"}
          </button>
        </div>
      )}

      <div className="glass-card" style={{ padding: 16, marginBottom: 24 }}>
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Paste one or many video/audio links…"
          style={{
            width: "100%",
            minHeight: 72,
            resize: "vertical",
            background: "var(--bg-elevated)",
            color: "var(--text-primary)",
            border: "1px solid var(--border)",
            borderRadius: "var(--r-sm)",
            padding: 10,
            fontFamily: "inherit",
            fontSize: 14,
          }}
        />
        <div style={{ display: "flex", gap: 8, marginTop: 12, alignItems: "center" }}>
          <div style={{ display: "flex", gap: 4 }}>
            {(["video", "audio"] as MediaType[]).map((t) => (
              <button
                key={t}
                className={mediaType === t ? "btn-primary" : "btn-glass"}
                onClick={() => setMediaType(t)}
              >
                {t === "video" ? "Video" : "Audio"}
              </button>
            ))}
          </div>
          <div style={{ flex: 1 }} />
          <button className="btn-primary" onClick={save} disabled={!ready}>
            Save to archive
          </button>
        </div>
      </div>

      <Section title={`Active (${active.length})`}>
        {active.length === 0 && <Empty>No active saves</Empty>}
        {active.map((i) => (
          <Row key={i.id} item={i} />
        ))}
      </Section>

      <Section title={`History (${history.length})`}>
        {history.length === 0 && <Empty>Nothing saved yet</Empty>}
        {history.map((i) => (
          <Row key={i.id} item={i} />
        ))}
      </Section>

      {settings && (
        <div style={{ marginTop: 28, color: "var(--text-secondary)", fontSize: 12 }}>
          Saving to {settings.downloadPath}
        </div>
      )}
    </div>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div style={{ marginBottom: 24 }}>
      <h2 style={{ fontSize: 14, textTransform: "uppercase", letterSpacing: 1, color: "var(--text-secondary)" }}>
        {title}
      </h2>
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>{children}</div>
    </div>
  );
}

function Empty({ children }: { children: ReactNode }) {
  return <div style={{ color: "var(--text-secondary)", fontSize: 13 }}>{children}</div>;
}

function Row({ item }: { item: DownloadItem }) {
  const pct = Math.round(item.progress.percent);
  return (
    <div className="glass-card" style={{ padding: 12 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
            {item.title}
          </div>
          <div style={{ fontSize: 12, color: "var(--text-secondary)" }}>
            {item.platform} · {item.status}
            {item.status === "downloading" &&
              ` · ${item.progress.speed ?? ""} · ETA ${item.progress.eta ?? ""}`}
            {item.status === "error" && item.errorMessage ? ` · ${item.errorMessage}` : ""}
          </div>
        </div>
        <RowActions item={item} />
      </div>
      {["downloading", "processing"].includes(item.status) && (
        <div style={{ marginTop: 8, height: 6, background: "var(--surface)", borderRadius: 3 }}>
          <div
            className="accent-gradient"
            style={{ width: `${pct}%`, height: "100%", borderRadius: 3, transition: "width .2s" }}
          />
        </div>
      )}
    </div>
  );
}

function RowActions({ item }: { item: DownloadItem }) {
  if (["pending", "downloading", "processing"].includes(item.status)) {
    return (
      <button className="btn-glass" onClick={() => api.cancelDownload(item.id)}>
        Cancel
      </button>
    );
  }
  return (
    <div style={{ display: "flex", gap: 6 }}>
      {item.status === "completed" && item.savedFilePath && (
        <>
          <button className="btn-glass" onClick={() => api.openPath(item.savedFilePath!)}>
            Play
          </button>
          <button className="btn-glass" onClick={() => api.revealInExplorer(item.savedFilePath!)}>
            Reveal
          </button>
        </>
      )}
      {item.status === "error" && (
        <button className="btn-glass" onClick={() => api.retryDownload(item.id)}>
          Retry
        </button>
      )}
      <button className="btn-glass" onClick={() => api.removeDownload(item.id)}>
        Remove
      </button>
    </div>
  );
}
