// Brand tint per platform, used for chips and icons.
import type { Platform } from "../api";

const COLORS: Record<string, string> = {
  YouTube: "#FF0033",
  TikTok: "#25F4EE",
  Instagram: "#E1306C",
  "X / Twitter": "#1DA1F2",
  Facebook: "#1877F2",
  Bilibili: "#00A1D6",
  Vimeo: "#1AB7EA",
  Twitch: "#9146FF",
  SoundCloud: "#FF5500",
  Reddit: "#FF4500",
  Dailymotion: "#0066DC",
  Web: "#8A8A8A",
};

const ICONS: Record<Platform, string> = {
  youtube: "play", tiktok: "music", instagram: "image", twitter: "globe",
  facebook: "globe", bilibili: "film", vimeo: "film", twitch: "film",
  soundcloud: "music", reddit: "globe", dailymotion: "film", generic: "globe",
};

const LABELS: Record<Platform, string> = {
  youtube: "YouTube", tiktok: "TikTok", instagram: "Instagram", twitter: "X / Twitter",
  facebook: "Facebook", bilibili: "Bilibili", vimeo: "Vimeo", twitch: "Twitch",
  soundcloud: "SoundCloud", reddit: "Reddit", dailymotion: "Dailymotion", generic: "Web",
};

export function brandColor(platform: Platform): string {
  return COLORS[LABELS[platform]] ?? "#8A8A8A";
}
export function platformIcon(platform: Platform): string {
  return ICONS[platform] ?? "globe";
}
export function platformLabel(platform: Platform): string {
  return LABELS[platform] ?? "Web";
}
