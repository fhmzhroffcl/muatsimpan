// Lightweight UI sound effects, gated by the user's `sfxEnabled` setting.
// Files live in public/sfx and are served at /sfx/<cue>.wav.

let enabled = true;
const cache: Record<string, HTMLAudioElement> = {};

export type Cue = "tap" | "toggle" | "save" | "complete" | "error";

export function setSfxEnabled(on: boolean) {
  enabled = on;
}

export function playSfx(cue: Cue) {
  if (!enabled) return;
  try {
    let a = cache[cue];
    if (!a) {
      a = new Audio(`/sfx/${cue}.wav`);
      a.volume = 0.35;
      cache[cue] = a;
    }
    a.currentTime = 0;
    void a.play().catch(() => {});
  } catch {
    /* ignore — sound is best-effort */
  }
}
