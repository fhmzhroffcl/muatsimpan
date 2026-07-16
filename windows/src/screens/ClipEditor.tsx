import * as React from "react";
import { useRef, useState } from "react";
import { api, fileSrc, type LibraryEntry } from "../api";
import { useApp } from "../lib/store";
import { Modal, Btn, Spinner } from "../ui/kit";
import { duration } from "../lib/format";

// Two-panel editor: video viewer on top, trim timeline + controls below.
// Exports via ffmpeg (api.exportEdit / api.exportClip).
const SPEEDS = [0.5, 1, 1.5, 2];
const ASPECTS = ["original", "1:1", "9:16", "16:9"];
const HEIGHTS: { label: string; value: number | null }[] = [
  { label: "Source", value: null },
  { label: "1080p", value: 1080 },
  { label: "720p", value: 720 },
  { label: "480p", value: 480 },
];

export function ClipEditor({ entry, onClose }: { entry: LibraryEntry; onClose: () => void }) {
  const { settings } = useApp();
  const my = settings.language === "malay";
  const videoRef = useRef<HTMLVideoElement>(null);
  const [dur, setDur] = useState(0);
  const [start, setStart] = useState(0);
  const [end, setEnd] = useState(0);
  const [speed, setSpeed] = useState(1);
  const [aspect, setAspect] = useState("original");
  const [maxHeight, setMaxHeight] = useState<number | null>(null);
  const [cropX, setCropX] = useState(0.5);
  const [cropY, setCropY] = useState(0.5);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  function onLoaded() {
    const d = videoRef.current?.duration ?? 0;
    setDur(d);
    setEnd(d);
  }
  function seek(t: number) {
    if (videoRef.current) videoRef.current.currentTime = t;
  }

  async function exportEdit() {
    setBusy(true); setError(null); setResult(null);
    try {
      const out = await api.exportEdit(entry.path, {
        start, end, speed, aspect, maxHeight, cropX, cropY,
      });
      setResult(out);
      api.libraryBrowse();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }
  async function quickTrim() {
    setBusy(true); setError(null); setResult(null);
    try {
      const out = await api.exportClip(entry.path, start, end);
      setResult(out);
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal onClose={onClose} width={720}>
      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
        <div style={{ fontSize: 16, fontWeight: 700, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{entry.name}</div>

        <video
          ref={videoRef}
          src={fileSrc(entry.path)}
          controls
          onLoadedMetadata={onLoaded}
          style={{
            width: "100%", background: "#000", borderRadius: 10,
            aspectRatio: aspect === "1:1" ? "1" : aspect === "9:16" ? "9/16" : aspect === "16:9" ? "16/9" : "16/9",
            objectFit: aspect === "original" ? "contain" : "cover",
            objectPosition: `${cropX * 100}% ${cropY * 100}%`,
            maxHeight: 320,
          }}
        />

        {/* Timeline */}
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <div style={{ display: "flex", justifyContent: "space-between", fontSize: 12, color: "var(--text-secondary)", fontVariantNumeric: "tabular-nums" }}>
            <span>{my ? "Mula" : "Start"} {duration(start)}</span>
            <span>{my ? "Tamat" : "End"} {duration(end)}</span>
          </div>
          <input type="range" min={0} max={dur || 1} step={0.1} value={start} onChange={(e) => { const v = Math.min(Number(e.target.value), end - 0.1); setStart(v); seek(v); }} style={{ width: "100%" }} />
          <input type="range" min={0} max={dur || 1} step={0.1} value={end} onChange={(e) => { const v = Math.max(Number(e.target.value), start + 0.1); setEnd(v); seek(v); }} style={{ width: "100%" }} />
        </div>

        {/* Controls */}
        <Field label={my ? "Kelajuan" : "Speed"}>
          {SPEEDS.map((s) => (
            <Pill key={s} label={`${s}×`} on={speed === s} onClick={() => setSpeed(s)} />
          ))}
        </Field>
        <Field label={my ? "Nisbah" : "Aspect"}>
          {ASPECTS.map((a) => (
            <Pill key={a} label={a === "original" ? (my ? "Asal" : "Original") : a} on={aspect === a} onClick={() => setAspect(a)} />
          ))}
        </Field>
        <Field label={my ? "Resolusi" : "Resolution"}>
          {HEIGHTS.map((h) => (
            <Pill key={h.label} label={h.label} on={maxHeight === h.value} onClick={() => setMaxHeight(h.value)} />
          ))}
        </Field>
        {aspect !== "original" && (
          <>
            <Field label={my ? "Fokus X" : "Focus X"}>
              <input type="range" min={0} max={1} step={0.01} value={cropX} onChange={(e) => setCropX(Number(e.target.value))} style={{ flex: 1 }} />
            </Field>
            <Field label={my ? "Fokus Y" : "Focus Y"}>
              <input type="range" min={0} max={1} step={0.01} value={cropY} onChange={(e) => setCropY(Number(e.target.value))} style={{ flex: 1 }} />
            </Field>
          </>
        )}

        {error && <div style={{ color: "#f87171", fontSize: 12 }}>{error}</div>}
        {result && <div style={{ color: "#4ade80", fontSize: 12 }}>{my ? "Disimpan:" : "Saved:"} {result}</div>}

        <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
          <Btn onClick={quickTrim} disabled={busy}>{my ? "Potong pantas" : "Quick trim"}</Btn>
          <Btn variant="primary" icon="scissors" onClick={exportEdit} disabled={busy}>
            {busy ? <Spinner size={14} /> : my ? "Eksport" : "Export"}
          </Btn>
          <Btn onClick={onClose}>{my ? "Tutup" : "Close"}</Btn>
        </div>
      </div>
    </Modal>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
      <span style={{ fontSize: 12, color: "var(--text-secondary)", width: 80, flexShrink: 0 }}>{label}</span>
      <div style={{ display: "flex", gap: 6, flexWrap: "wrap", flex: 1, alignItems: "center" }}>{children}</div>
    </div>
  );
}
function Pill({ label, on, onClick }: { label: string; on: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick} style={{ border: "1px solid " + (on ? "transparent" : "var(--border)"), fontSize: 12, fontWeight: 600, padding: "5px 12px", borderRadius: 999, color: on ? "#fff" : "var(--text-secondary)", background: on ? "linear-gradient(135deg,var(--accent),var(--accent2))" : "var(--surface-hover)" }}>{label}</button>
  );
}
