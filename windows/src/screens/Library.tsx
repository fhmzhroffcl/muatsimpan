import { useCallback, useEffect, useRef, useState } from "react";
import { api, fileSrc, onLibraryShouldRefresh, type BrowseResult, type LibraryEntry, type NoteWithEntry } from "../api";
import { useApp } from "../lib/store";
import { Icon } from "../ui/Icon";
import { IconButton } from "../ui/kit";
import { VideoThumb } from "../ui/VideoThumb";
import { bytes } from "../lib/format";
import { ClipEditor } from "./ClipEditor";
import { NoteEditor, NOTE_COLORS } from "./NoteEditor";

type Tab = "folders" | "media" | "player" | "editor";
type SortMode = "messy" | "name" | "date";
const CARD_W = 200, CARD_H = 178;
const isVideoPath = (p: string) => /\.(mp4|mkv|webm|mov|m4v)$/i.test(p);

export function Library({ onAddToArchive }: { onAddToArchive: () => void }) {
  const { settings, t } = useApp();
  const my = settings.language === "malay";
  const [tab, setTab] = useState<Tab>("media");
  const [search, setSearch] = useState("");
  const [browse, setBrowse] = useState<BrowseResult | null>(null);
  const [media, setMedia] = useState<LibraryEntry[]>([]);
  const [positions, setPositions] = useState<Record<string, [number, number]>>({});
  const [noteCounts, setNoteCounts] = useState<Record<string, number>>({});
  const [selecting, setSelecting] = useState(false);
  const [selection, setSelection] = useState<Set<string>>(new Set());
  const [sortMode, setSortMode] = useState<SortMode>("messy");
  const [clipEntry, setClipEntry] = useState<LibraryEntry | null>(null);
  const [noteEntry, setNoteEntry] = useState<LibraryEntry | null>(null);
  const [showNotes, setShowNotes] = useState(false);

  const refresh = useCallback(async (folder?: string) => {
    const [b, m, p, notes] = await Promise.all([
      api.libraryBrowse(folder), api.libraryAllMedia(), api.positions(), api.allNotes(),
    ]);
    setBrowse(b); setMedia(m); setPositions(p);
    const counts: Record<string, number> = {};
    for (const n of notes) counts[n.entry.path] = (counts[n.entry.path] ?? 0) + 1;
    setNoteCounts(counts);
  }, []);

  useEffect(() => {
    refresh();
    const un = onLibraryShouldRefresh(() => refresh(browse?.currentFolder));
    return () => { un.then((f) => f()); };
  }, []);

  const filterMatch = (e: LibraryEntry) => !search.trim() || e.name.toLowerCase().includes(search.toLowerCase());

  return (
    <div style={{ position: "relative", height: "100%", overflow: "hidden" }}>
      <div style={{ height: "100%", overflow: "auto" }}>
        {tab === "folders" && browse && (
          <FoldersCanvas browse={browse} positions={positions} noteCounts={noteCounts} sortMode={sortMode} search={search}
            onOpenFolder={(f) => refresh(f)} onRefresh={() => refresh(browse.currentFolder)}
            onClip={setClipEntry} onNote={setNoteEntry} filterMatch={filterMatch} />
        )}
        {tab === "media" && (
          <MediaTab media={media.filter(filterMatch)} noteCounts={noteCounts} selecting={selecting} selection={selection}
            onToggle={(e) => toggleSel(e)} onPlay={(e) => openPlayer(e)} onClip={setClipEntry} onNote={setNoteEntry}
            root={browse?.root ?? settings.downloadPath} totalSize={media.reduce((s, m) => s + m.size, 0)} count={media.length} my={my} onAddToArchive={onAddToArchive} />
        )}
        {tab === "player" && <PlayerTab media={media.filter(filterMatch)} initial={playerTarget} my={my} onTrash={async (e) => { await api.libraryTrash(e.path); refresh(); }} />}
        {tab === "editor" && <EditorTab videos={media.filter((m) => isVideoPath(m.path) && filterMatch(m))} onEdit={setClipEntry} my={my} />}
      </div>

      {/* Header */}
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, display: "flex", gap: 10, alignItems: "center", padding: "40px 24px 12px", background: "linear-gradient(var(--bg), transparent)", pointerEvents: "none" }}>
        <div style={{ display: "flex", gap: 8, alignItems: "center", pointerEvents: "auto" }}>
          {tab === "folders" && browse && !browse.isAtRoot && (
            <IconButton icon="chevronLeft" onClick={() => refresh(parentOf(browse.currentFolder))} />
          )}
          <span style={{ fontSize: 22, fontWeight: 800 }}>
            {tab === "folders" && browse && !browse.isAtRoot ? browse.currentFolder.split(/[\\/]/).pop() : t("nav.library")}
          </span>
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ display: "flex", gap: 6, alignItems: "center", pointerEvents: "auto" }}>
          <div style={{ display: "flex", gap: 6, alignItems: "center", padding: "7px 10px", borderRadius: 999, background: "var(--surface)", border: "1px solid var(--border)", maxWidth: 260 }}>
            <Icon name="search" size={15} style={{ color: "var(--text-secondary)" }} />
            <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder={t("lib.search")} style={{ border: "none", background: "transparent", padding: 0, width: 180 }} />
          </div>
          {tab === "media" && <IconButton icon="plus" title={my ? "Tambah ke arkib" : "Add to archive"} onClick={onAddToArchive} />}
          <IconButton icon="note" title={t("lib.allNotes")} onClick={() => setShowNotes((v) => !v)} />
          {tab === "folders" && <>
            <IconButton icon={sortMode === "messy" ? "grid" : sortMode === "name" ? "list" : "guide"} title={my ? "Susun" : "Arrange"} onClick={() => setSortMode((s) => (s === "messy" ? "name" : s === "name" ? "date" : "messy"))} />
            <IconButton icon="folder" title={t("lib.newFolder")} onClick={async () => { await api.libraryNewFolder(browse?.currentFolder ?? null, my ? "Folder Baharu" : "New Folder"); refresh(browse?.currentFolder); }} />
          </>}
          {(tab === "folders" || tab === "media") && (
            <IconButton icon={selecting ? "check" : "grid"} active={selecting} title={my ? "Pilih" : "Select"} onClick={() => { setSelecting((v) => !v); setSelection(new Set()); }} />
          )}
        </div>
      </div>

      {/* Floating nav */}
      <div style={{ position: "absolute", bottom: 22, left: 0, right: 0, display: "grid", placeItems: "center" }}>
        <div style={{ display: "flex", gap: 4, padding: 6, borderRadius: 999, background: "var(--bg-elevated)", border: "1px solid var(--border)", boxShadow: "0 18px 40px rgba(0,0,0,.24)" }}>
          {(["folders", "media", "player", "editor"] as Tab[]).map((tp) => (
            <button key={tp} onClick={() => setTab(tp)} style={{ display: "inline-flex", gap: 5, alignItems: "center", border: "none", borderRadius: 999, padding: tab === tp ? "9px 14px" : "9px 11px", background: tab === tp ? "var(--accent)" : "transparent", color: tab === tp ? "#fff" : "var(--text-secondary)", fontSize: 12, fontWeight: 600 }}>
              <Icon name={tp === "folders" ? "folder" : tp === "media" ? "grid" : tp === "player" ? "play" : "scissors"} size={13} />
              {tab === tp && t(`lib.${tp === "media" ? "media" : tp}`)}
            </button>
          ))}
        </div>
      </div>

      {showNotes && <NotesBrowser onOpen={(e) => { setShowNotes(false); setNoteEntry(e); }} onClose={() => setShowNotes(false)} my={my} />}
      {clipEntry && <ClipEditor entry={clipEntry} onClose={() => { setClipEntry(null); refresh(browse?.currentFolder); }} />}
      {noteEntry && <NoteEditor entry={noteEntry} onClose={() => { setNoteEntry(null); refresh(browse?.currentFolder); }} />}
    </div>
  );

  function toggleSel(e: LibraryEntry) {
    if (selecting) {
      setSelection((s) => { const n = new Set(s); n.has(e.id) ? n.delete(e.id) : n.add(e.id); return n; });
    } else {
      openPlayer(e);
    }
  }
  function openPlayer(e: LibraryEntry) { playerTarget = e; setTab("player"); }
}

let playerTarget: LibraryEntry | null = null;

function parentOf(p: string): string {
  const parts = p.split(/[\\/]/);
  parts.pop();
  return parts.join(p.includes("\\") ? "\\" : "/");
}

// ---- Media tab ----

function MediaTab({ media, noteCounts, selecting, selection, onToggle, onPlay, onClip, onNote, root, totalSize, count, my, onAddToArchive }: {
  media: LibraryEntry[]; noteCounts: Record<string, number>; selecting: boolean; selection: Set<string>;
  onToggle: (e: LibraryEntry) => void; onPlay: (e: LibraryEntry) => void; onClip: (e: LibraryEntry) => void; onNote: (e: LibraryEntry) => void;
  root: string; totalSize: number; count: number; my: boolean; onAddToArchive: () => void;
}) {
  const groups = groupByDay(media, my);
  return (
    <div style={{ padding: "96px 24px 96px", maxWidth: 1100, margin: "0 auto" }}>
      <div style={{ padding: 18, borderRadius: 12, background: "rgba(128,128,128,.05)", border: "1px solid var(--border)", marginBottom: 24 }}>
        <div style={{ display: "flex", alignItems: "center" }}>
          <div style={{ fontSize: 22, fontWeight: 800, flex: 1 }}>{my ? "Simpanan anda" : "Your archive"}</div>
          <button onClick={onAddToArchive} style={{ display: "inline-flex", gap: 5, alignItems: "center", border: "none", fontSize: 12, fontWeight: 600, padding: "6px 11px", borderRadius: 999, background: "var(--accent-soft)", color: "var(--accent)", cursor: "pointer" }}>
            <Icon name="plus" size={13} /> {my ? "Tambah ke arkib" : "Add to archive"}
          </button>
        </div>
        <div style={{ fontSize: 12, color: "var(--text-secondary)", marginTop: 6 }}>{count} {my ? "item" : "items"} · {bytes(totalSize)} {my ? "dalam simpanan anda" : "in your archive"}</div>
        <div style={{ fontSize: 11, fontFamily: "monospace", color: "var(--text-secondary)", marginTop: 4, display: "flex", gap: 6, alignItems: "center" }}>
          <Icon name="folder" size={12} style={{ color: "var(--accent)" }} /> {root}
        </div>
      </div>

      {media.length === 0 ? (
        <div style={{ textAlign: "center", paddingTop: 100, color: "var(--text-secondary)" }}>
          <Icon name="grid" size={44} style={{ opacity: 0.5 }} />
          <div style={{ fontSize: 18, fontWeight: 500, marginTop: 12, maxWidth: 400, marginInline: "auto" }}>
            {my ? "Platform boleh padam bila-bila. Simpan yang penting, milik anda selamanya." : "Platforms can remove things anytime. Save what matters — yours to keep."}
          </div>
        </div>
      ) : (
        groups.map(([day, items]) => (
          <div key={day} style={{ marginBottom: 24 }}>
            <div style={{ display: "flex", gap: 8, alignItems: "center", marginBottom: 10 }}>
              <span style={{ width: 6, height: 6, borderRadius: 999, background: "var(--accent)" }} />
              <span style={{ fontSize: 13, fontWeight: 700 }}>{day}</span>
              <span style={{ fontSize: 11, color: "var(--text-secondary)" }}>{items.length}</span>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(150px, 1fr))", gap: 16 }}>
              {items.map((e) => (
                <MediaCell key={e.id} entry={e} noteCount={noteCounts[e.path] ?? 0} selecting={selecting} selected={selection.has(e.id)}
                  onTap={() => onToggle(e)} onPlay={() => onPlay(e)} onClip={() => onClip(e)} onNote={() => onNote(e)} my={my} />
              ))}
            </div>
          </div>
        ))
      )}
    </div>
  );
}

function MediaCell({ entry, noteCount, selecting, selected, onTap, onPlay, onClip, onNote, my }: {
  entry: LibraryEntry; noteCount: number; selecting: boolean; selected: boolean;
  onTap: () => void; onPlay: () => void; onClip: () => void; onNote: () => void; my: boolean;
}) {
  const [hover, setHover] = useState(false);
  return (
    <div onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)} onDoubleClick={onPlay} onClick={onTap} style={{ cursor: "pointer", transform: hover ? "scale(1.02)" : "none", transition: "transform .15s" }}>
      <div style={{ position: "relative", aspectRatio: "16 / 9", borderRadius: 9, overflow: "hidden", border: selected ? "2.5px solid var(--accent)" : "1px solid var(--border)" }}>
        <VideoThumb path={entry.path} />
        {noteCount > 0 && (
          <span style={{ position: "absolute", left: 6, bottom: 6, display: "inline-flex", gap: 3, alignItems: "center", fontSize: 9, fontWeight: 700, color: "#fff", padding: "3px 5px", borderRadius: 999, background: "rgba(0,0,0,.55)" }}>
            <Icon name="note" size={8} /> {noteCount}
          </span>
        )}
        {selecting ? (
          <div style={{ position: "absolute", top: 6, right: 6, color: selected ? "var(--accent)" : "#fff" }}><Icon name={selected ? "check" : "grid"} size={16} /></div>
        ) : hover ? (
          <div style={{ position: "absolute", top: 6, right: 6, display: "flex", gap: 4 }}>
            <MiniAct icon="scissors" title={my ? "Klip" : "Clip"} onClick={onClip} />
            <MiniAct icon="note" title={my ? "Nota" : "Note"} onClick={onNote} />
          </div>
        ) : null}
      </div>
      <div style={{ fontSize: 11, fontWeight: 500, marginTop: 7, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{entry.name}</div>
      <div style={{ fontSize: 9, color: "var(--text-secondary)", fontFamily: "monospace" }}>{entry.path.split(".").pop()?.toUpperCase()} · {bytes(entry.size)}</div>
    </div>
  );
}

function MiniAct({ icon, title, onClick }: { icon: string; title: string; onClick: () => void }) {
  return (
    <button title={title} onClick={(e) => { e.stopPropagation(); onClick(); }} className="icon-btn" style={{ width: 24, height: 24, background: "rgba(0,0,0,.4)", color: "#fff" }}>
      <Icon name={icon} size={11} />
    </button>
  );
}

// ---- Folders canvas ----

function FoldersCanvas({ browse, positions, noteCounts, sortMode, search, onOpenFolder, onRefresh, onClip, onNote, filterMatch }: {
  browse: BrowseResult; positions: Record<string, [number, number]>; noteCounts: Record<string, number>;
  sortMode: SortMode; search: string; onOpenFolder: (f: string) => void; onRefresh: () => void;
  onClip: (e: LibraryEntry) => void; onNote: (e: LibraryEntry) => void; filterMatch: (e: LibraryEntry) => boolean;
}) {
  const { settings } = useApp();
  const my = settings.language === "malay";
  let entries = browse.entries.filter(filterMatch);
  if (sortMode === "name") entries = [...entries].sort((a, b) => a.name.localeCompare(b.name));
  if (sortMode === "date") entries = [...entries].sort((a, b) => b.modified - a.modified);

  const [local, setLocal] = useState<Record<string, [number, number]>>({});
  const drag = useRef<{ id: string; ox: number; oy: number; moved: boolean } | null>(null);
  const [renaming, setRenaming] = useState<string | null>(null);

  const posOf = (e: LibraryEntry, i: number): [number, number] => local[e.path] ?? positions[e.path] ?? gridPos(i);

  function onPointerDown(ev: React.PointerEvent, e: LibraryEntry, i: number) {
    if (sortMode !== "messy") return;
    const [x, y] = posOf(e, i);
    drag.current = { id: e.path, ox: ev.clientX - x, oy: ev.clientY - y, moved: false };
    (ev.target as HTMLElement).setPointerCapture(ev.pointerId);
  }
  function onPointerMove(ev: React.PointerEvent) {
    if (!drag.current) return;
    const d = drag.current;
    d.moved = true;
    setLocal((l) => ({ ...l, [d.id]: [ev.clientX - d.ox, ev.clientY - d.oy] }));
  }
  async function onPointerUp(ev: React.PointerEvent) {
    const d = drag.current;
    drag.current = null;
    if (!d || !d.moved) return;
    const dropped = [ev.clientX - d.ox, ev.clientY - d.oy] as [number, number];
    // Did we drop onto a folder card?
    const target = entries.find((e, i) => {
      if (!e.isFolder || e.path === d.id) return false;
      const [fx, fy] = posOf(e, i);
      return Math.abs(fx - dropped[0]) < CARD_W && Math.abs(fy - dropped[1]) < CARD_H;
    });
    if (target) {
      await api.libraryMove([d.id], target.path);
      onRefresh();
    } else {
      await api.setPosition(d.id, dropped[0], dropped[1]);
    }
  }

  return (
    <div style={{ position: "relative", width: 2600, height: 1800, padding: 0 }}
      onPointerMove={onPointerMove} onPointerUp={onPointerUp}>
      <div style={{ position: "absolute", inset: 0, backgroundImage: "radial-gradient(circle, var(--border) 1px, transparent 1px)", backgroundSize: "26px 26px", opacity: 0.5 }} />
      {entries.map((e, i) => {
        const [x, y] = posOf(e, i);
        return (
          <div key={e.path} onPointerDown={(ev) => onPointerDown(ev, e, i)}
            onDoubleClick={() => (e.isFolder ? onOpenFolder(e.path) : (playerTarget = e))}
            style={{ position: "absolute", left: x, top: y, width: CARD_W, cursor: sortMode === "messy" ? "grab" : "default", userSelect: "none" }}>
            <div style={{ borderRadius: 12, overflow: "hidden", border: "1px solid var(--border)", background: "var(--surface)", boxShadow: "0 6px 16px rgba(0,0,0,.14)" }}>
              <div style={{ height: 118, position: "relative", background: "var(--surface-hover)", display: "grid", placeItems: "center" }}>
                {e.isFolder ? <Icon name="folder" size={44} style={{ color: "var(--accent)" }} /> : <VideoThumb path={e.path} radius={0} />}
                {!e.isFolder && (
                  <div className="card-actions" style={{ position: "absolute", top: 6, right: 6, display: "flex", gap: 4 }}>
                    <MiniAct icon="scissors" title="Clip" onClick={() => onClip(e)} />
                    <MiniAct icon="note" title="Note" onClick={() => onNote(e)} />
                  </div>
                )}
                {(noteCounts[e.path] ?? 0) > 0 && (
                  <span style={{ position: "absolute", left: 6, bottom: 6, fontSize: 9, fontWeight: 700, color: "#fff", padding: "2px 5px", borderRadius: 999, background: "rgba(0,0,0,.5)" }}>
                    <Icon name="note" size={8} /> {noteCounts[e.path]}
                  </span>
                )}
              </div>
              <div style={{ padding: "8px 10px" }}>
                {renaming === e.path ? (
                  <input autoFocus defaultValue={e.name} onBlur={(ev) => finishRename(e, ev.target.value)} onKeyDown={(ev) => { if (ev.key === "Enter") finishRename(e, (ev.target as HTMLInputElement).value); }} style={{ width: "100%", fontSize: 12, padding: "2px 4px" }} />
                ) : (
                  <div onDoubleClick={(ev) => { ev.stopPropagation(); setRenaming(e.path); }} style={{ fontSize: 12, fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{e.name}</div>
                )}
                <div style={{ fontSize: 10, color: "var(--text-secondary)" }}>{e.isFolder ? (my ? "Folder" : "Folder") : bytes(e.size)}</div>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );

  async function finishRename(e: LibraryEntry, name: string) {
    setRenaming(null);
    if (name.trim() && name.trim() !== e.name) { await api.libraryRename(e.path, name.trim()); onRefresh(); }
  }
}

function gridPos(i: number): [number, number] {
  const perRow = Math.max(1, Math.floor((2600 - 120) / 230));
  return [150 + (i % perRow) * 230, 220 + Math.floor(i / perRow) * 210];
}

// ---- Player tab ----

function PlayerTab({ media, initial, my, onTrash }: { media: LibraryEntry[]; initial: LibraryEntry | null; my: boolean; onTrash: (e: LibraryEntry) => void }) {
  const [index, setIndex] = useState(() => {
    const i = initial ? media.findIndex((m) => m.path === initial.path) : 0;
    return i >= 0 ? i : 0;
  });
  const [showList, setShowList] = useState(false);
  const current = media[index];
  const videoRef = useRef<HTMLVideoElement>(null);

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: "96px 40px 100px", gap: 16 }}>
      <div style={{ width: "100%", maxWidth: 900 }}>
        {current ? (
          <video ref={videoRef} key={current.path} src={fileSrc(current.path)} controls style={{ width: "100%", aspectRatio: "16 / 9", borderRadius: 12, background: "#000" }} />
        ) : (
          <div style={{ aspectRatio: "16 / 9", borderRadius: 12, background: "var(--surface)", display: "grid", placeItems: "center" }}><Icon name="play" size={48} style={{ color: "var(--text-secondary)" }} /></div>
        )}
      </div>
      {current && <div style={{ fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", maxWidth: 600 }}>{current.name}</div>}
      <div style={{ display: "flex", gap: 14, alignItems: "center", position: "relative" }}>
        <Ctl icon="chevronLeft" onClick={() => setIndex((i) => (i - 1 + media.length) % Math.max(1, media.length))} />
        <Ctl icon="play" onClick={() => videoRef.current?.play()} />
        <Ctl icon="pause" onClick={() => videoRef.current?.pause()} />
        <Ctl icon="chevronRight" onClick={() => setIndex((i) => (i + 1) % Math.max(1, media.length))} />
        <Ctl icon="trash" onClick={() => current && onTrash(current)} />
        <div style={{ position: "relative" }}>
          <Ctl icon="list" badge={media.length} onClick={() => setShowList((v) => !v)} />
          {showList && (
            <div className="glass-card" style={{ position: "absolute", bottom: 54, left: "50%", transform: "translateX(-50%)", width: 300, maxHeight: 360, overflow: "auto", padding: 8, zIndex: 20 }}>
              {media.map((e, i) => (
                <button key={e.path} onClick={() => { setIndex(i); setShowList(false); }} style={{ display: "flex", gap: 8, alignItems: "center", width: "100%", border: "none", background: i === index ? "var(--accent-soft)" : "transparent", borderRadius: 8, padding: "7px 10px", cursor: "pointer", textAlign: "left" }}>
                  <Icon name={i === index ? "play" : "film"} size={13} style={{ color: i === index ? "var(--accent)" : "var(--text-secondary)" }} />
                  <span style={{ fontSize: 12, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{e.name}</span>
                </button>
              ))}
              {media.length === 0 && <div style={{ padding: 16, textAlign: "center", color: "var(--text-secondary)", fontSize: 12 }}>{my ? "Tiada media lagi" : "No media yet"}</div>}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function Ctl({ icon, badge, onClick }: { icon: string; badge?: number; onClick: () => void }) {
  return (
    <button onClick={onClick} className="icon-btn" style={{ width: 44, height: 44, background: "var(--surface)", border: "1px solid var(--border)", position: "relative" }}>
      <Icon name={icon} size={18} />
      {badge ? <span style={{ position: "absolute", top: -3, right: -3, fontSize: 9, fontWeight: 700, color: "#fff", background: "var(--accent)", borderRadius: 999, padding: "1px 5px" }}>{badge}</span> : null}
    </button>
  );
}

// ---- Editor tab ----

function EditorTab({ videos, onEdit, my }: { videos: LibraryEntry[]; onEdit: (e: LibraryEntry) => void; my: boolean }) {
  return (
    <div style={{ padding: "96px 28px 100px", maxWidth: 1100, margin: "0 auto" }}>
      <div style={{ display: "flex", gap: 12, alignItems: "center", marginBottom: 20 }}>
        <div style={{ width: 38, height: 38, borderRadius: 999, background: "var(--accent-soft)", color: "var(--accent)", display: "grid", placeItems: "center" }}><Icon name="scissors" size={18} /></div>
        <div>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{my ? "Editor Video" : "Video Editor"}</div>
          <div style={{ fontSize: 12, color: "var(--text-secondary)" }}>{my ? "Pilih video untuk potong, krop, dan laraskan kelajuan." : "Pick a video to trim, crop, and adjust speed."}</div>
        </div>
      </div>
      {videos.length === 0 ? (
        <div style={{ textAlign: "center", paddingTop: 80, color: "var(--text-secondary)" }}><Icon name="scissors" size={44} style={{ opacity: 0.5 }} /><div style={{ marginTop: 12 }}>{my ? "Tiada video lagi." : "No videos yet."}</div></div>
      ) : (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))", gap: 16 }}>
          {videos.map((e) => (
            <button key={e.path} onClick={() => onEdit(e)} style={{ border: "1px solid var(--border)", borderRadius: 12, overflow: "hidden", background: "var(--surface)", cursor: "pointer", padding: 0, textAlign: "left" }}>
              <div style={{ aspectRatio: "16 / 9" }}><VideoThumb path={e.path} radius={0} /></div>
              <div style={{ padding: "8px 10px", fontSize: 12, fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{e.name}</div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// ---- Notes browser ----

function NotesBrowser({ onOpen, onClose, my }: { onOpen: (e: LibraryEntry) => void; onClose: () => void; my: boolean }) {
  const [notes, setNotes] = useState<NoteWithEntry[]>([]);
  useEffect(() => { api.allNotes().then(setNotes); }, []);
  return (
    <div onClick={onClose} style={{ position: "fixed", inset: 0, zIndex: 60 }}>
      <div onClick={(e) => e.stopPropagation()} className="glass-card" style={{ position: "absolute", top: 84, right: 24, width: 320, maxHeight: 460, overflow: "auto", padding: 12 }}>
        <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>{my ? "Semua nota" : "All notes"}</div>
        {notes.length === 0 && <div style={{ fontSize: 12, color: "var(--text-secondary)" }}>{my ? "Tiada nota lagi." : "No notes yet."}</div>}
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {notes.map((n, i) => (
            <button key={i} onClick={() => onOpen(n.entry)} style={{ border: "none", textAlign: "left", cursor: "pointer", borderRadius: 10, padding: 10, background: NOTE_COLORS[n.note.color] ?? NOTE_COLORS.yellow, color: "rgba(0,0,0,.78)" }}>
              <div style={{ fontSize: 12, fontWeight: 600, marginBottom: 3 }}>{n.note.text}</div>
              <div style={{ fontSize: 10, opacity: 0.7 }}>{n.entry.name}</div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ---- helpers ----

function groupByDay(media: LibraryEntry[], my: boolean): [string, LibraryEntry[]][] {
  const fmt = new Intl.DateTimeFormat(my ? "ms-MY" : "en", { weekday: "long", day: "numeric", month: "long", year: "numeric" });
  const map = new Map<string, LibraryEntry[]>();
  for (const e of media) {
    const key = fmt.format(new Date(e.modified));
    if (!map.has(key)) map.set(key, []);
    map.get(key)!.push(e);
  }
  return [...map.entries()].sort((a, b) => (b[1][0]?.modified ?? 0) - (a[1][0]?.modified ?? 0));
}
