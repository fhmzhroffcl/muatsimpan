import { useState } from "react";
import { type ContainerOption, type MediaType, type MediaProbe } from "../api";
import { useApp } from "../lib/store";
import { GlassCard, Btn, Icon } from "../ui/kit";
import { Thumbnail } from "../ui/Thumbnail";
import { heightLabel, estimatedSize } from "../lib/probe";
import { bytes, duration, compactCount } from "../lib/format";
import { platformLabel } from "../lib/brand";
import type { Pending } from "./Archive";

const CONTAINERS: { id: ContainerOption; label: string }[] = [
  { id: "auto", label: "Auto" },
  { id: "mp4", label: "MP4" },
  { id: "mkv", label: "MKV" },
  { id: "webm", label: "WEBM" },
  { id: "original", label: "Original" },
];

export function PendingCard({
  pending,
  onChange,
  onRemove,
  onDownload,
}: {
  pending: Pending;
  onChange: (patch: Partial<Pending>) => void;
  onRemove: () => void;
  onDownload: () => void;
}) {
  const { settings } = useApp();
  const my = settings.language === "malay";
  const [expanded, setExpanded] = useState(false);
  const probe = pending.probe;

  return (
    <GlassCard radius={12} glow={!!probe} style={{ padding: 16, display: "flex", flexDirection: "column", gap: 14 }}>
      <div style={{ display: "flex", gap: 14, alignItems: "flex-start" }}>
        <div style={{ position: "relative" }}>
          <Thumbnail src={probe?.thumbnail} platform={pending.platform} width={156} height={88} />
          {probe?.duration ? (
            <span style={{ position: "absolute", right: 5, bottom: 5, fontSize: 9, fontWeight: 700, padding: "2px 5px", borderRadius: 5, background: "rgba(0,0,0,.7)", color: "#fff" }}>{duration(probe.duration)}</span>
          ) : null}
        </div>

        <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 5 }}>
          {probe ? (
            <>
              <div style={{ fontSize: 15, fontWeight: 600, display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>{probe.title}</div>
              <div style={{ display: "flex", gap: 6, alignItems: "center", flexWrap: "wrap" }}>
                <span style={{ display: "inline-flex", gap: 3, alignItems: "center", fontSize: 10, fontWeight: 700, color: "#fff", padding: "3px 7px", borderRadius: 999, background: "linear-gradient(135deg,var(--accent),var(--accent2))" }}>
                  {platformLabel(pending.platform)}
                </span>
                {probe.channel && <span style={{ fontSize: 12, color: "var(--text-secondary)" }}>{probe.channel}</span>}
                {probe.viewCount ? <span style={{ fontSize: 12, color: "var(--text-secondary)" }}>· {compactCount(probe.viewCount)} {my ? "tontonan" : "views"}</span> : null}
              </div>
              {probe.description && (
                <>
                  <div style={{ fontSize: 12, color: "var(--text-secondary)", display: expanded ? "block" : "-webkit-box", WebkitLineClamp: expanded ? undefined : 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>{probe.description}</div>
                  <button onClick={() => setExpanded((e) => !e)} style={{ alignSelf: "flex-start", border: "none", background: "transparent", color: "var(--accent)", fontSize: 10, fontWeight: 600, padding: 0 }}>
                    {my ? (expanded ? "Tutup" : "Baca lagi") : expanded ? "Show less" : "Read more"}
                  </button>
                </>
              )}
            </>
          ) : pending.error ? (
            <>
              <div style={{ fontSize: 12, color: "var(--text-secondary)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{pending.url}</div>
              <div style={{ display: "flex", gap: 6, alignItems: "center", fontSize: 12, color: "#fb923c" }}>
                <Icon name="info" size={13} /> {pending.error}
              </div>
            </>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: 7 }}>
              <div className="skeleton" style={{ width: 200, height: 13 }} />
              <div className="skeleton" style={{ width: 130, height: 10 }} />
              <div style={{ fontSize: 12, color: "var(--text-secondary)" }}>{my ? "Membaca maklumat video…" : "Reading video info…"}</div>
            </div>
          )}
        </div>

        <button onClick={onRemove} className="icon-btn" style={{ width: 26, height: 26, background: "var(--surface)" }}>
          <Icon name="x" size={12} />
        </button>
      </div>

      {probe && <Controls pending={pending} probe={probe} onChange={onChange} onDownload={onDownload} my={my} />}
    </GlassCard>
  );
}

function Controls({
  pending,
  probe,
  onChange,
  onDownload,
  my,
}: {
  pending: Pending;
  probe: MediaProbe;
  onChange: (patch: Partial<Pending>) => void;
  onDownload: () => void;
  my: boolean;
}) {
  const size = estimatedSize(probe, pending.selectedHeight ?? probe.heights[0] ?? null);
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
        {(["video", "audio"] as MediaType[]).map((tp) => {
          const on = pending.type === tp;
          return (
            <button key={tp} onClick={() => onChange({ type: tp })} className={on ? "btn-primary" : "btn-glass"} style={{ borderRadius: 999 }}>
              <span style={{ display: "inline-flex", gap: 6, alignItems: "center" }}>
                <Icon name={tp === "video" ? "film" : "music"} size={13} />
                {tp === "video" ? (my ? "Video" : "Video") : "Audio"}
              </span>
            </button>
          );
        })}
        <div style={{ flex: 1 }} />
        {pending.type === "video" && size ? (
          <span style={{ fontSize: 10, fontWeight: 600, color: "#4ade80", background: "rgba(74,222,128,.14)", padding: "4px 8px", borderRadius: 999 }}>≈ {bytes(size)}</span>
        ) : null}
      </div>

      {pending.type === "video" && probe.heights.length > 0 && (
        <>
          <div style={{ display: "flex", gap: 7, overflowX: "auto", paddingBottom: 2 }}>
            <QualityChip label={my ? "Terbaik" : "Best"} on={pending.selectedHeight == null} onClick={() => onChange({ selectedHeight: null })} />
            {probe.heights.map((h) => (
              <QualityChip key={h} label={heightLabel(h)} sparkle={h >= 4320} on={pending.selectedHeight === h} onClick={() => onChange({ selectedHeight: h })} />
            ))}
          </div>
          <div style={{ display: "flex", gap: 7, alignItems: "center", flexWrap: "wrap" }}>
            <span style={{ fontSize: 12, color: "var(--text-secondary)" }}>{my ? "Format" : "Format"}</span>
            {CONTAINERS.map((c) => {
              const on = pending.container === c.id;
              return (
                <button key={c.id} onClick={() => onChange({ container: c.id })} style={{ border: "none", fontSize: 11, fontWeight: 600, padding: "5px 10px", borderRadius: 999, color: on ? "#fff" : "var(--text-secondary)", background: on ? "var(--accent)" : "var(--surface-hover)" }}>{c.label}</button>
              );
            })}
          </div>
        </>
      )}

      <Btn variant="primary" icon="archive" onClick={onDownload}>{my ? "Simpan ini" : "Save this"}</Btn>
    </div>
  );
}

function QualityChip({ label, on, sparkle, onClick }: { label: string; on: boolean; sparkle?: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      style={{
        border: "1px solid " + (on ? "transparent" : "var(--border)"),
        display: "inline-flex", gap: 4, alignItems: "center", whiteSpace: "nowrap",
        fontSize: 12, fontWeight: 700, padding: "7px 13px", borderRadius: 999,
        color: on ? "#fff" : "var(--text-primary)",
        background: on ? "linear-gradient(135deg,var(--accent),var(--accent2))" : "var(--surface-hover)",
        transform: on ? "scale(1.05)" : "none",
        boxShadow: on ? "0 4px 12px var(--accent-soft)" : "none",
      }}
    >
      {sparkle && "✦"} {label}
    </button>
  );
}
