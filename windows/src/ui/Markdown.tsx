// Lightweight markdown renderer for the legal docs — headings, bullets, and
// inline bold/italic. Port of MarkdownDoc in MainView.swift. Not a full parser.

import type { ReactNode } from "react";

function inline(s: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  const re = /(\*\*([^*]+)\*\*|\*([^*]+)\*|`([^`]+)`)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let key = 0;
  while ((m = re.exec(s))) {
    if (m.index > last) nodes.push(s.slice(last, m.index));
    if (m[2]) nodes.push(<strong key={key++}>{m[2]}</strong>);
    else if (m[3]) nodes.push(<em key={key++}>{m[3]}</em>);
    else if (m[4]) nodes.push(<code key={key++}>{m[4]}</code>);
    last = m.index + m[0].length;
  }
  if (last < s.length) nodes.push(s.slice(last));
  return nodes;
}

export function Markdown({ text }: { text: string }) {
  const lines = text.split("\n");
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 7 }}>
      {lines.map((raw, i) => {
        const s = raw.trim();
        if (!s) return <div key={i} style={{ height: 3 }} />;
        if (s.startsWith("# ")) return <div key={i} style={{ fontSize: 18, fontWeight: 700, color: "var(--text-primary)" }}>{inline(s.slice(2))}</div>;
        if (s.startsWith("## ")) return <div key={i} style={{ fontSize: 14, fontWeight: 700, color: "var(--text-primary)", paddingTop: 4 }}>{inline(s.slice(3))}</div>;
        if (s.startsWith("### ")) return <div key={i} style={{ fontSize: 12.5, fontWeight: 600, color: "var(--text-primary)" }}>{inline(s.slice(4))}</div>;
        if (s.startsWith("- ") || s.startsWith("* "))
          return (
            <div key={i} style={{ display: "flex", gap: 6, alignItems: "flex-start" }}>
              <span style={{ color: "var(--accent)" }}>•</span>
              <span style={{ fontSize: 12, color: "var(--text-secondary)" }}>{inline(s.slice(2))}</span>
            </div>
          );
        return <div key={i} style={{ fontSize: 12, color: "var(--text-secondary)", lineHeight: 1.6 }}>{inline(s)}</div>;
      })}
    </div>
  );
}
