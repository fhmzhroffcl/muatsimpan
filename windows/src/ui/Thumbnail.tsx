import { useState } from "react";
import type { Platform } from "../api";
import { Icon } from "./Icon";
import { platformIcon } from "../lib/brand";

// Remote thumbnail with a platform-glyph fallback. Also used for local file
// posters (pass a file:// asset src).
export function Thumbnail({
  src,
  platform,
  width = 128,
  height = 74,
  radius = 9,
}: {
  src?: string | null;
  platform: Platform;
  width?: number | string;
  height?: number | string;
  radius?: number;
}) {
  const [failed, setFailed] = useState(false);
  return (
    <div
      style={{
        width, height, borderRadius: radius, background: "var(--surface-hover)",
        display: "grid", placeItems: "center", overflow: "hidden", flexShrink: 0, position: "relative",
      }}
    >
      {src && !failed ? (
        <img
          src={src}
          onError={() => setFailed(true)}
          style={{ width: "100%", height: "100%", objectFit: "cover" }}
        />
      ) : (
        <Icon name={platformIcon(platform)} size={22} style={{ color: "var(--text-secondary)" }} />
      )}
    </div>
  );
}
