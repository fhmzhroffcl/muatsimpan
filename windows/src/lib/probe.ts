// Media-probe helpers mirrored from MediaProbe (Swift) so the pending-download
// card can compute labels and size estimates without a round-trip.

import type { MediaProbe } from "../api";

export function heightLabel(h: number): string {
  if (h >= 4320) return "8K";
  if (h >= 2160) return "4K";
  if (h >= 1440) return "2K";
  return `${h}p`;
}

export function estimatedSize(probe: MediaProbe, height: number | null): number | null {
  const audioSizes = probe.formats
    .filter((f) => (f.vcodec ?? "none") === "none" && (f.acodec ?? "none") !== "none")
    .map((f) => f.filesize ?? 0);
  const audio = audioSizes.length ? Math.max(...audioSizes) : 0;
  if (height != null) {
    const videoSizes = probe.formats
      .filter((f) => (f.vcodec ?? "none") !== "none" && f.height === height)
      .map((f) => f.filesize ?? 0)
      .filter((n) => n > 0);
    if (!videoSizes.length) return null;
    return Math.max(...videoSizes) + audio;
  }
  return audio > 0 ? audio : null;
}

export function extractLinks(text: string): string[] {
  const re = /https?:\/\/[^\s)\]}"'>]+/g;
  const seen = new Set<string>();
  const out: string[] = [];
  for (const m of text.matchAll(re)) {
    const cleaned = m[0].replace(/[).,\]}"'>]+$/, "");
    if (!seen.has(cleaned)) {
      seen.add(cleaned);
      out.push(cleaned);
    }
  }
  return out;
}
