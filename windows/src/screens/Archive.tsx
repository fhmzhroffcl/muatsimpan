import { useEffect, useRef, useState } from "react";
import { open } from "@tauri-apps/plugin-dialog";
import { api, type ContainerOption, type DownloadItem, type MediaProbe, type MediaType, type Platform } from "../api";
import { useApp } from "../lib/store";
import { Icon } from "../ui/Icon";
import { Btn } from "../ui/kit";
import { extractLinks, heightLabel, estimatedSize } from "../lib/probe";
import { DownloadRow } from "./DownloadRow";
import { PendingCard } from "./PendingCard";
import { ActivityDockLabel } from "./ActivityDock";

export interface Pending {
  id: string;
  url: string;
  platform: Platform;
  probe: MediaProbe | null;
  error: string | null;
  type: MediaType;
  selectedHeight: number | null;
  container: ContainerOption;
}

export function Archive() {
  const { settings, updateSettings, active, recentlyFinished, engineReady, greet } = useApp();
  const my = settings.language === "malay";
  const [input, setInput] = useState("");
  const [pending, setPending] = useState<Pending[]>([]);
  const [greetText, setGreetText] = useState(greet());
  const debounce = useRef<number | null>(null);

  const detected = extractLinks(input);

  useEffect(() => {
    const id = window.setInterval(() => setGreetText(greet()), 150000);
    return () => window.clearInterval(id);
  }, [settings.language, settings.userName]);

  function patch(id: string, p: Partial<Pending>) {
    setPending((list) => list.map((x) => (x.id === id ? { ...x, ...p } : x)));
  }

  async function probeOne(item: Pending) {
    try {
      const probe = await api.probeMedia(item.url);
      patch(item.id, { probe });
    } catch (e) {
      patch(item.id, { error: String(e) });
    }
  }

  function fetchDetected() {
    if (!engineReady) return;
    const existing = new Set(pending.map((p) => p.url));
    const fresh = detected.filter((u) => !existing.has(u));
    if (!fresh.length) return;
    const items: Pending[] = fresh.map((url) => ({
      id: crypto.randomUUID(),
      url,
      platform: detectPlatform(url),
      probe: null,
      error: null,
      type: "video",
      selectedHeight: null,
      container: settings.container,
    }));
    setPending((list) => [...list, ...items]);
    setInput("");
    items.forEach(probeOne);
  }

  useEffect(() => {
    if (debounce.current) window.clearTimeout(debounce.current);
    if (detected.length && engineReady) {
      debounce.current = window.setTimeout(fetchDetected, 500);
    }
    return () => {
      if (debounce.current) window.clearTimeout(debounce.current);
    };
  }, [input]);

  async function fetchNow() {
    if (!detected.length) {
      try {
        const clip = await navigator.clipboard.readText();
        if (extractLinks(clip).length) {
          setInput(clip);
          return;
        }
      } catch { /* clipboard blocked */ }
    }
    fetchDetected();
  }

  function enqueueOne(p: Pending) {
    api.enqueuePrepared([toItem(p)]);
    setPending((list) => list.filter((x) => x.id !== p.id));
  }
  function enqueueAll() {
    const ready = pending.filter((p) => p.probe);
    api.enqueuePrepared(ready.map(toItem));
    setPending((list) => list.filter((p) => !p.probe));
  }

  async function pickFolder() {
    const picked = await open({ directory: true, defaultPath: settings.downloadPath });
    if (typeof picked === "string") updateSettings({ downloadPath: picked });
  }

  const probing = pending.filter((p) => !p.probe && !p.error);
  const resolved = pending.filter((p) => p.probe || p.error);
  const recent = recentlyFinished.slice(0, 50);
  const empty = !active.length && !recent.length && !pending.length;

  return (
    <div style={{ position: "relative", height: "100%" }}>
      <div style={{ height: "100%", overflow: "auto", padding: 24, paddingBottom: 70 }}>
        <div style={{ maxWidth: 720, margin: "0 auto", display: "flex", flexDirection: "column", gap: 18 }}>
          <div style={{ paddingTop: 34 }}>
            <div onClick={() => setGreetText(greet())} style={{ fontSize: 24, fontWeight: 800, cursor: "pointer" }}>{greetText}</div>
            <div style={{ color: "var(--text-secondary)", marginTop: 4 }}>{my ? "Tambah media ke arkib anda" : "Add media to your archive"}</div>
          </div>

          <div style={{ display: "flex", gap: 12, padding: 16, borderRadius: 12, background: "rgba(128,128,128,.06)", border: "1px solid var(--border)" }}>
            <div style={{ width: 42, height: 42, borderRadius: 999, background: "var(--accent-soft)", color: "var(--accent)", display: "grid", placeItems: "center", flexShrink: 0 }}>
              <Icon name="archive" size={20} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 16, fontWeight: 700 }}>{my ? "Simpan ke arkib" : "Save to archive"}</div>
              <div style={{ fontSize: 12, color: "var(--text-secondary)", marginTop: 2 }}>{my ? "Tambah media ke simpanan peribadi anda. Fail disimpan terus di peranti sendiri." : "Add media to your personal collection. Files are saved directly on your own device."}</div>
              <button onClick={pickFolder} style={{ display: "inline-flex", gap: 6, alignItems: "center", marginTop: 6, border: "none", background: "transparent", color: "var(--text-secondary)", fontFamily: "monospace", fontSize: 11, padding: 0, cursor: "pointer" }}>
                <Icon name="folder" size={12} style={{ color: "var(--accent)" }} />
                <span style={{ maxWidth: 420, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{settings.downloadPath}</span>
                <Icon name="chevronRight" size={11} />
              </button>
            </div>
          </div>

          <div style={{ display: "flex", gap: 10, alignItems: "flex-start", padding: 14, borderRadius: 16, background: "var(--surface)", border: "1px solid var(--border)" }}>
            <Icon name="external" size={16} style={{ color: detected.length ? "var(--accent)" : "var(--text-secondary)", marginTop: 8 }} />
            <textarea
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); fetchNow(); } }}
              placeholder={my ? "Tampal satu atau banyak pautan video/audio…" : "Paste one or many video/audio links…"}
              rows={1}
              style={{ flex: 1, border: "none", background: "transparent", resize: "none", padding: "7px 0", fontSize: 15, minHeight: 20, maxHeight: 160 }}
            />
            <Btn variant="primary" icon="archive" onClick={fetchNow}>{my ? "Simpan" : "Save"}</Btn>
          </div>

          {probing.length > 0 && (
            <div style={{ display: "flex", gap: 10, alignItems: "center", padding: "11px 14px", borderRadius: 9, background: "var(--surface)", border: "1px solid var(--border)" }}>
              <span className="spinner" style={{ width: 16, height: 16 }} />
              <span style={{ fontSize: 13, fontWeight: 500, color: "var(--text-secondary)" }}>{my ? "Menyemak daripada" : "Checking from"}</span>
              <span style={{ fontSize: 13, fontWeight: 700, color: "var(--accent)" }}>{probing.length} item</span>
            </div>
          )}

          {resolved.length > 0 && (
            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              <SectionHeader title={my ? "Sedia disimpan" : "Ready to save"} onClear={() => setPending([])} clearLabel={my ? "Kosongkan" : "Clear"} />
              {resolved.map((p) => (
                <PendingCard key={p.id} pending={p} onChange={(patchP) => patch(p.id, patchP)} onRemove={() => setPending((l) => l.filter((x) => x.id !== p.id))} onDownload={() => enqueueOne(p)} />
              ))}
              {pending.length > 1 && (
                <Btn variant="primary" icon="archive" onClick={enqueueAll} style={{ justifyContent: "center" }} disabled={!pending.some((p) => p.probe)}>
                  {(my ? "Simpan Semua" : "Save All") + ` (${pending.length})`}
                </Btn>
              )}
            </div>
          )}

          {active.length > 0 && (
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              <div style={{ fontSize: 15, fontWeight: 700, paddingTop: 6 }}>{my ? "Sedang menyimpan" : "Saving"}</div>
              {active.map((i) => <DownloadRow key={i.id} item={i} />)}
            </div>
          )}

          {recent.length > 0 && (
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              <div style={{ fontSize: 15, fontWeight: 700, color: "var(--text-secondary)", paddingTop: 10 }}>{my ? "Baru diarkibkan" : "Recently archived"}</div>
              {recent.map((i) => <DownloadRow key={i.id} item={i} faded />)}
            </div>
          )}

          {empty && (
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12, paddingTop: 60, color: "var(--text-secondary)" }}>
              <Icon name="download" size={40} style={{ opacity: 0.5 }} />
              <div>{my ? "Tampal pautan, pilih, dan simpan ke arkib." : "Paste a link, choose your format, and save it to your archive."}</div>
            </div>
          )}
        </div>
      </div>

      <div style={{ position: "absolute", bottom: 16, left: 0, right: 0, display: "grid", placeItems: "center", pointerEvents: "none" }}>
        <div style={{ pointerEvents: "auto" }}><ActivityDockLabel /></div>
      </div>
    </div>
  );
}

function SectionHeader({ title, onClear, clearLabel }: { title: string; onClear: () => void; clearLabel: string }) {
  return (
    <div style={{ display: "flex", alignItems: "center" }}>
      <div style={{ fontSize: 15, fontWeight: 700, flex: 1 }}>{title}</div>
      <button onClick={onClear} style={{ border: "none", background: "transparent", color: "var(--text-secondary)", fontSize: 12, cursor: "pointer" }}>{clearLabel}</button>
    </div>
  );
}

function detectPlatform(url: string): Platform {
  const u = url.toLowerCase();
  if (u.includes("youtube.com") || u.includes("youtu.be")) return "youtube";
  if (u.includes("tiktok.com")) return "tiktok";
  if (u.includes("instagram.com")) return "instagram";
  if (u.includes("twitter.com") || u.includes("x.com")) return "twitter";
  if (u.includes("facebook.com") || u.includes("fb.watch")) return "facebook";
  if (u.includes("bilibili.com")) return "bilibili";
  if (u.includes("vimeo.com")) return "vimeo";
  if (u.includes("twitch.tv")) return "twitch";
  if (u.includes("soundcloud.com")) return "soundcloud";
  if (u.includes("reddit.com")) return "reddit";
  if (u.includes("dailymotion.com")) return "dailymotion";
  return "generic";
}

function toItem(p: Pending): DownloadItem {
  const probe = p.probe;
  const h = p.selectedHeight ?? probe?.heights[0] ?? null;
  const qualityLabel = p.type === "audio" ? "Audio MP3" : p.selectedHeight != null ? heightLabel(p.selectedHeight) : "Best";
  const formatSelector = p.type === "video" && p.selectedHeight != null
    ? `bestvideo[height<=${p.selectedHeight}]+bestaudio/best[height<=${p.selectedHeight}]/best`
    : null;
  return {
    id: crypto.randomUUID(),
    url: p.url,
    title: probe?.title ?? p.url,
    thumbnailUrl: probe?.thumbnail ?? null,
    type: p.type,
    status: "pending",
    progress: { percent: 0 },
    errorMessage: null,
    log: "",
    duration: probe?.duration ?? null,
    fileSize: null,
    savedFilePath: null,
    uploader: probe?.uploader ?? null,
    channel: probe?.channel ?? null,
    descriptionText: probe?.description ?? null,
    viewCount: probe?.viewCount ?? null,
    platform: p.platform,
    formatNote: h != null && p.type === "video" ? heightLabel(h) : null,
    ext: p.type === "audio" ? "mp3" : p.container === "auto" ? "mp4" : p.container,
    audioFormat: null,
    quality: "best",
    container: p.container,
    formatSelector,
    qualityLabel,
    estimatedSize: probe ? estimatedSize(probe, h) : null,
    createdAt: Date.now(),
    completedAt: null,
  };
}
