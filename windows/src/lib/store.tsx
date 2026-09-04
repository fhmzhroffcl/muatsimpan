// App-wide state: settings (persisted), live downloads, engine readiness, and a
// language-bound translator. Mirrors the shared singletons on the macOS side.

import { createContext, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import {
  api, onDownloadsUpdated, type AppSettings, type DownloadItem, type MediaType,
} from "../api";
import { applyTheme } from "./theme";
import { greeting, loc } from "./i18n";
import { setSfxEnabled, playSfx } from "./sfx";

interface AppCtx {
  settings: AppSettings;
  updateSettings: (patch: Partial<AppSettings>) => void;
  downloads: DownloadItem[];
  active: DownloadItem[];
  history: DownloadItem[];
  recentlyFinished: DownloadItem[];
  engineReady: boolean;
  refreshEngine: () => void;
  t: (key: string) => string;
  greet: () => string;
  enqueue: (urls: string[], type?: MediaType) => Promise<void>;
  activityOpen: boolean;
  openActivity: () => void;
  closeActivity: () => void;
}

const Ctx = createContext<AppCtx | null>(null);

export function AppProvider({ settings: initial, children }: { settings: AppSettings; children: ReactNode }) {
  const [settings, setSettings] = useState<AppSettings>(initial);
  const [downloads, setDownloads] = useState<DownloadItem[]>([]);
  const [engineReady, setEngineReady] = useState(false);
  const [activityOpen, setActivityOpen] = useState(false);
  const persistTimer = useRef<number | null>(null);
  const prevStatus = useRef<Record<string, string>>({});

  useEffect(() => {
    applyTheme(settings);
    setSfxEnabled(settings.sfxEnabled);
    api.getDownloads().then((d) => {
      prevStatus.current = Object.fromEntries(d.map((i) => [i.id, i.status]));
      setDownloads(d);
    });
    api.engineReady().then(setEngineReady);
    const un = onDownloadsUpdated((d) => {
      // Play a cue when an item finishes or fails.
      for (const i of d) {
        const was = prevStatus.current[i.id];
        if (was && was !== i.status) {
          if (i.status === "completed") playSfx("complete");
          else if (i.status === "error") playSfx("error");
        }
      }
      prevStatus.current = Object.fromEntries(d.map((i) => [i.id, i.status]));
      setDownloads(d);
    });
    return () => { un.then((f) => f()); };
  }, []);

  function updateSettings(patch: Partial<AppSettings>) {
    setSettings((prev) => {
      const next = { ...prev, ...patch };
      applyTheme(next);
      setSfxEnabled(next.sfxEnabled);
      // Debounced persistence to the Rust side.
      if (persistTimer.current) window.clearTimeout(persistTimer.current);
      persistTimer.current = window.setTimeout(() => api.saveSettings(next), 250);
      return next;
    });
  }

  const active = useMemo(
    () => downloads.filter((i) => ["pending", "downloading", "processing"].includes(i.status)),
    [downloads]
  );
  const history = useMemo(
    () => downloads.filter((i) => ["completed", "error", "cancelled"].includes(i.status)),
    [downloads]
  );
  const recentlyFinished = useMemo(
    () =>
      downloads
        .filter((i) => i.status === "completed")
        .sort((a, b) => (b.completedAt ?? 0) - (a.completedAt ?? 0)),
    [downloads]
  );

  const value: AppCtx = {
    settings,
    updateSettings,
    downloads,
    active,
    history,
    recentlyFinished,
    engineReady,
    refreshEngine: () => api.engineReady().then(setEngineReady),
    t: (key) => loc(key, settings.language),
    greet: () => greeting(settings.language, settings.userName),
    enqueue: (urls, type) => { playSfx("save"); return api.enqueueUrls(urls, type); },
    activityOpen,
    openActivity: () => setActivityOpen(true),
    closeActivity: () => setActivityOpen(false),
  };

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useApp(): AppCtx {
  const c = useContext(Ctx);
  if (!c) throw new Error("useApp outside provider");
  return c;
}
