// Accent palette + theme/pattern application — port of DesignSystem.swift.

import type { AppSettings } from "../api";

export interface AccentOption {
  id: string;
  name: string;
  hex: string;
  hex2: string;
}

// Malaysian-inspired accent palette (matches AccentPalette.options).
export const ACCENTS: AccentOption[] = [
  { id: "sunset", name: "Senja", hex: "#F1592A", hex2: "#E23A2E" },
  { id: "bungaraya", name: "Bunga Raya", hex: "#E0243B", hex2: "#B01029" },
  { id: "songket", name: "Songket", hex: "#E0A126", hex2: "#D4841A" },
  { id: "tehtarik", name: "Teh Tarik", hex: "#C97B3C", hex2: "#A5602A" },
  { id: "rafflesia", name: "Rafflesia", hex: "#D84327", hex2: "#A83218" },
  { id: "pandan", name: "Pandan", hex: "#4FA85A", hex2: "#3B8C46" },
  { id: "laut", name: "Laut", hex: "#2E9AA6", hex2: "#1F7C86" },
];

export const PATTERNS = ["none", "batik", "songket", "bungaRaya", "klcc"] as const;
export type PatternStyle = (typeof PATTERNS)[number];

export function patternLabel(p: PatternStyle, malay: boolean): string {
  switch (p) {
    case "none": return malay ? "Tiada" : "None";
    case "batik": return "Batik";
    case "songket": return "Songket";
    case "bungaRaya": return "Bunga Raya";
    case "klcc": return "KLCC";
  }
}

export function resolveTheme(settings: AppSettings): "light" | "dark" {
  if (settings.appearance === "system") {
    return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
  }
  return settings.appearance;
}

export function applyTheme(settings: AppSettings) {
  const root = document.documentElement;
  root.dataset.accent = settings.accent;
  root.dataset.theme = resolveTheme(settings);
}

// A subtle tiling Malaysian motif rendered as an inline SVG data URI, used as a
// faint background on panels (replaces the SwiftUI Canvas patterns).
export function patternDataUri(style: PatternStyle, hex: string, opacity = 0.06): string | null {
  if (style === "none") return null;
  const stroke = hexA(hex, opacity);
  const fill = hexA(hex, opacity);
  let inner = "";
  let size = 46;
  switch (style) {
    case "batik":
      size = 46;
      inner = `<circle cx="0" cy="0" r="10" fill="none" stroke="${stroke}"/><circle cx="0" cy="0" r="4" fill="${fill}"/>
               <circle cx="46" cy="0" r="10" fill="none" stroke="${stroke}"/><circle cx="0" cy="46" r="10" fill="none" stroke="${stroke}"/>
               <circle cx="46" cy="46" r="10" fill="none" stroke="${stroke}"/>`;
      break;
    case "songket":
      size = 30;
      inner = `<path d="M0 -6 L6 0 L0 6 L-6 0 Z" fill="none" stroke="${stroke}"/>
               <path d="M30 24 L36 30 L30 36 L24 30 Z" fill="none" stroke="${stroke}"/>`;
      break;
    case "bungaRaya":
      size = 58;
      inner = petals(0, 0, stroke) + petals(58, 0, stroke) + petals(0, 58, stroke) + petals(58, 58, stroke) + petals(29, 29, stroke);
      break;
    case "klcc":
      size = 40;
      inner = `<path d="M6 40 L6 8 L11 -2 L16 8 L16 40" fill="none" stroke="${stroke}"/>
               <path d="M26 40 L26 14 L31 6 L36 14 L36 40" fill="none" stroke="${stroke}"/>`;
      break;
  }
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${inner}</svg>`;
  return `url("data:image/svg+xml,${encodeURIComponent(svg)}")`;
}

function petals(cx: number, cy: number, stroke: string): string {
  let s = "";
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    const x = cx + Math.cos(a) * 8 - 4;
    const y = cy + Math.sin(a) * 8 - 7;
    s += `<ellipse cx="${x + 4}" cy="${y + 7}" rx="4" ry="7" fill="none" stroke="${stroke}" stroke-width="0.8"/>`;
  }
  return s;
}

function hexA(hex: string, alpha: number): string {
  const n = parseInt(hex.replace("#", ""), 16);
  const r = (n >> 16) & 0xff, g = (n >> 8) & 0xff, b = n & 0xff;
  return `rgba(${r},${g},${b},${alpha})`;
}

export function accentOf(id: string): AccentOption {
  return ACCENTS.find((a) => a.id === id) ?? ACCENTS[0];
}
