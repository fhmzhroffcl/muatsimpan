import { useState } from "react";
import { api, type DownloadItem, type LibraryEntry } from "../api";
import { useApp } from "../lib/store";
import { Icon } from "../ui/Icon";
import { IconButton, PatternBg } from "../ui/kit";
import { accentOf, type PatternStyle } from "../lib/theme";
import { timeAgo } from "../lib/format";
import { MiniPlayer } from "./MiniPlayer";
import { ClipEditor } from "./ClipEditor";

// Docked pill at the bottom of the archive page — opens the floating window.
export function ActivityDockLabel() {
  const { active, openActivity, t } = useApp();
  const count = active.length;
  const overall = count ? active.reduce((s, i) => s + Math.min(i.progress.percent, 100), 0) / count : 0;

  return (
    <button
      onClick={openActivity}
      className="glass-card"
      style={{
        display: "inline-flex", alignItems: "center", gap: 9, padding: "9px 14px", borderRadius: 999,
        border: "1px solid " + (count ? "var(--accent)" : "var(--border)"),
        color: count ? "var(--accent)" : "var(--text-secondary)", background: "var(--glass)", cursor: "pointer",
      }}
    >
      {count > 0 ? <Ring pct={overall} /> : <Icon name="library" size={13} />}
      <span style={{ fontSize: 12, fontWeight: 600 }}>{t("activity.title")}</span>
      {count > 0 && <span style={{ fontSize: 11, fontVariantNumeric: "tabular-nums" }}>· {count} · {Math.round(overall)}%</span>}
    </button>
  );
}

function Ring({ pct }: { pct: number }) {
  const r = 7, c = 2 * Math.PI * r;
  return (
    <svg width={16} height={16} viewBox="0 0 16 16">
      <circle cx="8" cy="8" r={r} fill="none" stroke="var(--border)" strokeWidth="2" />
      <circle cx="8" cy="8" r={r} fill="none" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" strokeDasharray={c} strokeDashoffset={c * (1 - pct / 100)} transform="rotate(-90 8 8)" />
    </svg>
  );
}

// The floating window overlay, rendered globally from MainLayout.
export function ActivityDock() {
  const { activityOpen, closeActivity, settings, active, history, t } = useApp();
  const [tab, setTab] = useState<"active" | "history">("active");
  const [player, setPlayer] = useState<DownloadItem | null>(null);
  const [clip, setClip] = useState<LibraryEntry | null>(null);
  const accent = accentOf(settings.accent);
  const shown = tab === "active" ? active : history;

  if (!activityOpen) return null;

  return (
    <>
      <div onClick={closeActivity} style={{ position: "fixed", inset: 0, zIndex: 40 }} />
      <div
        className="glass-card"
        onClick={(e) => e.stopPropagation()}
        style={{ position: "fixed", right: 20, bottom: 20, width: 340, height: 440, zIndex: 41, display: "flex", flexDirection: "column", overflow: "hidden" }}
      >
        <PatternBg pattern={settings.pattern as PatternStyle} accentHex={accent.hex} opacity={0.06} radius={12} />
        <div style={{ position: "relative", display: "flex", flexDirection: "column", height: "100%" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "12px 14px 8px" }}>
            <Icon name="library" size={14} style={{ color: "var(--accent)" }} />
            <span style={{ fontSize: 13, fontWeight: 700, flex: 1 }}>{t("activity.title")}</span>
            <IconButton icon="x" size={24} title="Minimise" onClick={closeActivity} />
          </div>

          <div className="segmented" style={{ margin: "0 12px 10px" }}>
            {(["active", "history"] as const).map((tp) => (
              <button key={tp} className={tab === tp ? "seg-active" : ""} onClick={() => setTab(tp)} style={{ flex: 1 }}>
                {t(tp === "active" ? "activity.active" : "activity.history")} {(tp === "active" ? active.length : history.length) || ""}
              </button>
            ))}
          </div>

          {tab === "history" && history.length > 0 && (
            <div style={{ display: "flex", justifyContent: "flex-end", padding: "0 14px 8px" }}>
              <button onClick={() => api.clearHistory()} style={{ border: "none", background: "transparent", color: "#f87171", fontSize: 11, fontWeight: 500, cursor: "pointer", display: "inline-flex", gap: 4, alignItems: "center" }}>
                <Icon name="trash" size={12} /> {t("act.clearHistory")}
              </button>
            </div>
          )}

          <div style={{ flex: 1, overflow: "auto", padding: "0 12px 16px", display: "flex", flexDirection: "column", gap: 8 }}>
            {shown.length === 0 ? (
              <div style={{ margin: "auto", textAlign: "center", color: "var(--text-secondary)", display: "flex", flexDirection: "column", gap: 8, alignItems: "center" }}>
                <Icon name="download" size={28} style={{ opacity: 0.5 }} />
                <span style={{ fontSize: 12 }}>{tab === "active" ? t("activity.empty") : t("activity.history")}</span>
              </div>
            ) : (
              shown.map((i) => (
                <ActivityRow key={i.id} item={i} onPlay={() => setPlayer(i)} onEdit={() => setClip(toEntry(i))} malay={settings.language === "malay"} t={t} />
              ))
            )}
          </div>
        </div>
      </div>

      {player && player.savedFilePath && <MiniPlayer path={player.savedFilePath} title={player.title} onClose={() => setPlayer(null)} />}
      {clip && <ClipEditor entry={clip} onClose={() => setClip(null)} />}
    </>
  );
}

function ActivityRow({ item, onPlay, onEdit, t }: { item: DownloadItem; onPlay: () => void; onEdit: () => void; malay: boolean; t: (k: string) => string }) {
  const isVideo = !!item.savedFilePath && /\.(mp4|mkv|webm|mov|m4v)$/i.test(item.savedFilePath);
  return (
    <div style={{ padding: 10, borderRadius: 12, background: "rgba(128,128,128,.05)" }}>
      <div style={{ display: "flex", gap: 8, alignItems: "flex-start" }}>
        <StatusIcon status={item.status} />
        <span style={{ fontSize: 12, fontWeight: 500, flex: 1, display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>{item.title}</span>
      </div>
      {item.status === "downloading" && (
        <div style={{ marginTop: 6 }}>
          <div style={{ height: 4, background: "var(--border)", borderRadius: 999 }}>
            <div style={{ width: `${Math.min(item.progress.percent, 100)}%`, height: "100%", background: "var(--accent)", borderRadius: 999 }} />
          </div>
          <div style={{ display: "flex", justifyContent: "space-between", fontSize: 9, color: "var(--text-secondary)", marginTop: 3 }}>
            <span>{Math.round(item.progress.percent)}%</span>
            {item.progress.speed && <span>{item.progress.speed}</span>}
          </div>
        </div>
      )}
      {item.status === "completed" && (
        <div style={{ display: "flex", gap: 6, alignItems: "center", marginTop: 6 }}>
          <span style={{ fontSize: 9, color: "var(--text-secondary)", flex: 1 }}>{timeAgo(item.completedAt)}</span>
          {item.savedFilePath && <>
            <MiniBtn icon="play" title={t("act.playInApp")} onClick={onPlay} />
            {isVideo && <MiniBtn icon="scissors" title={t("act.edit")} onClick={onEdit} />}
            <MiniBtn icon="search" title={t("act.reveal")} onClick={() => api.revealInExplorer(item.savedFilePath!)} />
          </>}
          <MiniBtn icon="trash" title={t("act.remove")} onClick={() => api.removeDownload(item.id)} />
        </div>
      )}
      {item.status === "error" && (
        <div style={{ display: "flex", gap: 6, justifyContent: "flex-end", marginTop: 6 }}>
          <MiniBtn icon="refresh" title={t("act.retry")} onClick={() => api.retryDownload(item.id)} />
          <MiniBtn icon="trash" title={t("act.remove")} onClick={() => api.removeDownload(item.id)} />
        </div>
      )}
    </div>
  );
}

function MiniBtn({ icon, title, onClick }: { icon: string; title: string; onClick: () => void }) {
  return (
    <button onClick={onClick} title={title} className="icon-btn" style={{ width: 22, height: 22, background: "rgba(128,128,128,.12)" }}>
      <Icon name={icon} size={11} />
    </button>
  );
}

function StatusIcon({ status }: { status: DownloadItem["status"] }) {
  if (status === "completed") return <Icon name="check" size={13} style={{ color: "#4ade80", marginTop: 1 }} />;
  if (status === "error") return <Icon name="info" size={13} style={{ color: "#f87171", marginTop: 1 }} />;
  if (status === "cancelled") return <Icon name="x" size={13} style={{ color: "var(--text-secondary)", marginTop: 1 }} />;
  if (status === "downloading" || status === "processing") return <span className="spinner" style={{ width: 12, height: 12, marginTop: 1 }} />;
  return <Icon name="download" size={13} style={{ color: "var(--text-secondary)", marginTop: 1 }} />;
}

function toEntry(item: DownloadItem): LibraryEntry {
  const path = item.savedFilePath!;
  const name = path.split(/[\\/]/).pop() ?? path;
  return { id: path, path, name, isFolder: false, size: item.fileSize ?? 0, modified: item.completedAt ?? Date.now(), isMedia: true };
}
