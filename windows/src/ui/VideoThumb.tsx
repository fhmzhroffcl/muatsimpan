import { useRef } from "react";
import { fileSrc } from "../api";
import { Icon } from "./Icon";

// Shows a poster frame from a local video by seeking a little past the start.
// Audio files fall back to a waveform glyph.
export function VideoThumb({ path, radius = 9 }: { path: string; radius?: number }) {
  const ref = useRef<HTMLVideoElement>(null);
  const isAudio = /\.(mp3|m4a|wav|flac|opus|ogg)$/i.test(path);

  if (isAudio) {
    return (
      <div style={{ width: "100%", height: "100%", borderRadius: radius, background: "var(--surface-hover)", display: "grid", placeItems: "center" }}>
        <Icon name="music" size={26} style={{ color: "var(--accent)" }} />
      </div>
    );
  }

  return (
    <video
      ref={ref}
      src={fileSrc(path) + "#t=1"}
      muted
      preload="metadata"
      onLoadedMetadata={() => { if (ref.current && ref.current.currentTime === 0) ref.current.currentTime = 1; }}
      style={{ width: "100%", height: "100%", objectFit: "cover", borderRadius: radius, background: "#000" }}
    />
  );
}
