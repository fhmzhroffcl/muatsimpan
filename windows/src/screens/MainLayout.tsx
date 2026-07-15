import { useState } from "react";
import { useApp } from "../lib/store";
import { Logo, IconButton, PatternBg } from "../ui/kit";
import { Icon } from "../ui/Icon";
import { accentOf, type PatternStyle } from "../lib/theme";
import { AboutModal } from "./AboutModal";
import { Archive } from "./Archive";
import { Library } from "./Library";
import { Guide } from "./Guide";
import { Settings } from "./Settings";
import { ActivityDock } from "./ActivityDock";

type Section = "library" | "archive" | "guide" | "settings";
const SECTIONS: { id: Section; icon: string; key: string }[] = [
  { id: "library", icon: "library", key: "nav.library" },
  { id: "archive", icon: "archive", key: "nav.archive" },
  { id: "guide", icon: "guide", key: "nav.guide" },
  { id: "settings", icon: "settings", key: "nav.settings" },
];

export function MainLayout() {
  const { settings, t, active } = useApp();
  const [section, setSection] = useState<Section>("library");
  const [collapsed, setCollapsed] = useState(false);
  const [aboutOpen, setAboutOpen] = useState(false);
  const accent = accentOf(settings.accent);
  const pattern = settings.pattern as PatternStyle;

  return (
    <div style={{ position: "fixed", inset: 0, display: "flex", background: "var(--bg)" }}>
      {!collapsed && (
        <aside className="sidebar">
          <PatternBg pattern={pattern} accentHex={accent.hex} opacity={0.05} />
          <div style={{ position: "relative", display: "flex", flexDirection: "column", height: "100%" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "40px 16px 22px" }}>
              <Logo size={36} />
              <span style={{ fontSize: 15, fontWeight: 600, flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {settings.userName || "Hai"}
              </span>
              <IconButton icon="sidebar" size={28} title="Collapse" onClick={() => setCollapsed(true)} />
            </div>

            <nav style={{ display: "flex", flexDirection: "column", gap: 4, padding: "0 10px" }}>
              {SECTIONS.map((s) => (
                <button key={s.id} className={`nav-btn ${section === s.id ? "active" : ""}`} onClick={() => setSection(s.id)}>
                  <Icon name={s.icon} size={18} />
                  <span>{t(s.key)}</span>
                  {s.id === "archive" && active.length > 0 && <span className="nav-badge">{active.length}</span>}
                </button>
              ))}
            </nav>

            <div style={{ flex: 1 }} />

            <div style={{ padding: "0 10px 14px" }}>
              <button className="nav-btn" onClick={() => setAboutOpen(true)}>
                <Icon name="info" size={18} />
                <span>{t("nav.about")}</span>
              </button>
            </div>
          </div>
        </aside>
      )}

      {collapsed && (
        <div style={{ position: "absolute", left: 16, top: "50%", transform: "translateY(-50%)", zIndex: 10 }}>
          <div className="glass-card" style={{ padding: 8, display: "flex", flexDirection: "column", gap: 8, alignItems: "center", position: "relative" }}>
            <PatternBg pattern={pattern} accentHex={accent.hex} opacity={0.07} radius={12} />
            <button style={{ border: "none", background: "transparent" }} onClick={() => setCollapsed(false)} title="Expand"><Logo size={34} /></button>
            <div style={{ width: 22, height: 1, background: "var(--border)" }} />
            {SECTIONS.map((s) => (
              <div key={s.id} style={{ position: "relative" }}>
                <IconButton icon={s.icon} size={42} active={section === s.id} title={t(s.key)} onClick={() => setSection(s.id)} />
                {s.id === "archive" && active.length > 0 && (
                  <span style={{ position: "absolute", top: -2, right: -2, fontSize: 9, fontWeight: 700, color: "#fff", background: "var(--accent)", borderRadius: 999, padding: "1px 5px" }}>{active.length}</span>
                )}
              </div>
            ))}
            <div style={{ width: 22, height: 1, background: "var(--border)" }} />
            <IconButton icon="info" size={42} title={t("nav.about")} onClick={() => setAboutOpen(true)} />
          </div>
        </div>
      )}

      <main style={{ flex: 1, minWidth: 0, position: "relative", paddingLeft: collapsed ? 82 : 0 }}>
        {section === "archive" && <Archive />}
        {section === "library" && <Library onAddToArchive={() => setSection("archive")} />}
        {section === "guide" && <Guide />}
        {section === "settings" && <Settings />}
      </main>

      <ActivityDock />

      {aboutOpen && <AboutModal onClose={() => setAboutOpen(false)} />}
    </div>
  );
}
