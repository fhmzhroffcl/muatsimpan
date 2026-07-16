import { useEffect, useState } from "react";
import { api, type LibraryEntry, type NoteSize, type StickyNote } from "../api";
import { useApp } from "../lib/store";
import { Modal, Btn } from "../ui/kit";
import { Icon } from "../ui/Icon";

const COLORS: Record<string, string> = {
  yellow: "#F2C84B", pink: "#F27BA9", blue: "#6FA8F2", green: "#6FCB7E",
  orange: "#F2954B", purple: "#B07BE0", teal: "#4FC3C9",
};
const SIZES: { id: NoteSize; my: string; en: string }[] = [
  { id: "square", my: "Segi empat", en: "Square" },
  { id: "wide", my: "Melintang", en: "Wide" },
  { id: "big", my: "Besar", en: "Big" },
  { id: "tall", my: "Menegak", en: "Tall" },
];

export function NoteEditor({ entry, onClose }: { entry: LibraryEntry; onClose: () => void }) {
  const { settings } = useApp();
  const my = settings.language === "malay";
  const [notes, setNotes] = useState<StickyNote[]>([]);
  const [text, setText] = useState("");
  const [color, setColor] = useState("yellow");
  const [size, setSize] = useState<NoteSize>("square");

  async function reload() { setNotes(await api.notesFor(entry.path)); }
  useEffect(() => { reload(); }, [entry.path]);

  async function add() {
    if (!text.trim() || notes.length >= 5) return;
    await api.upsertNote(entry.path, { id: crypto.randomUUID(), text: text.trim(), color, size });
    setText("");
    reload();
  }
  async function remove(id: string) {
    await api.removeNote(entry.path, id);
    reload();
  }

  return (
    <Modal onClose={onClose} width={480}>
      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
        <div style={{ fontSize: 16, fontWeight: 700 }}>{my ? "Nota" : "Notes"} · {entry.name}</div>

        {notes.length > 0 && (
          <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
            {notes.map((n) => (
              <div key={n.id} style={{ position: "relative", width: 128, minHeight: 96, padding: 12, borderRadius: 10, background: COLORS[n.color] ?? COLORS.yellow, color: "rgba(0,0,0,.78)", fontSize: 12, fontWeight: 600, boxShadow: "0 6px 14px rgba(0,0,0,.18)" }}>
                {n.text}
                <button onClick={() => remove(n.id)} style={{ position: "absolute", top: 4, right: 4, border: "none", background: "rgba(0,0,0,.15)", borderRadius: 999, width: 18, height: 18, display: "grid", placeItems: "center", cursor: "pointer" }}>
                  <Icon name="x" size={10} />
                </button>
              </div>
            ))}
          </div>
        )}

        {notes.length < 5 ? (
          <>
            <textarea value={text} onChange={(e) => setText(e.target.value)} placeholder={my ? "Tulis nota…" : "Write a note…"} style={{ minHeight: 72, resize: "vertical" }} />
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <span style={{ fontSize: 12, color: "var(--text-secondary)" }}>{my ? "Warna" : "Color"}</span>
              {Object.entries(COLORS).map(([id, hex]) => (
                <button key={id} onClick={() => setColor(id)} style={{ width: 20, height: 20, borderRadius: 999, background: hex, border: color === id ? "2px solid var(--text-primary)" : "2px solid transparent" }} />
              ))}
            </div>
            <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
              <span style={{ fontSize: 12, color: "var(--text-secondary)" }}>{my ? "Saiz" : "Size"}</span>
              {SIZES.map((s) => (
                <button key={s.id} onClick={() => setSize(s.id)} className={size === s.id ? "btn-primary" : "btn-glass"} style={{ padding: "5px 10px", fontSize: 12 }}>{my ? s.my : s.en}</button>
              ))}
            </div>
            <Btn variant="primary" icon="plus" onClick={add} disabled={!text.trim()}>{my ? "Tambah nota" : "Add note"}</Btn>
          </>
        ) : (
          <div style={{ fontSize: 12, color: "var(--text-secondary)" }}>{my ? "Maksimum 5 nota setiap item." : "Maximum 5 notes per item."}</div>
        )}
      </div>
    </Modal>
  );
}

export const NOTE_COLORS = COLORS;
