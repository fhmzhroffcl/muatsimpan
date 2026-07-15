// Localization + greetings — port of Localization.swift (L table) and
// Greetings.swift. Language comes from settings; loc() falls back to the key.

import type { AppLanguage } from "../api";

type Table = Record<string, Partial<Record<AppLanguage, string>>>;

const table: Table = {
  // Sidebar
  "nav.archive": { malay: "Arkib", english: "Archive" },
  "nav.library": { malay: "Pustaka", english: "Library" },
  "nav.guide": { malay: "Panduan", english: "Guide" },
  "nav.settings": { malay: "Tetapan", english: "Settings" },
  "nav.about": { malay: "Perihal", english: "About" },
  // Download page
  "dl.placeholder": { malay: "Tampal satu atau banyak pautan video/audio…", english: "Paste one or many video/audio links…" },
  "dl.fetchingFrom": { malay: "Menyemak daripada", english: "Checking from" },
  "dl.fetch": { malay: "Simpan", english: "Save" },
  "dl.paste": { malay: "Tampal", english: "Paste" },
  "dl.download": { malay: "Simpan ke arkib", english: "Save to archive" },
  "dl.downloadAll": { malay: "Simpan Semua", english: "Save All" },
  "dl.readmore": { malay: "Baca lagi", english: "Read more" },
  "dl.readless": { malay: "Tutup", english: "Show less" },
  "dl.reading": { malay: "Membaca maklumat video…", english: "Reading video info…" },
  "dl.recent": { malay: "Baru diarkibkan", english: "Recently archived" },
  "dl.downloading": { malay: "Sedang menyimpan", english: "Saving" },
  "dl.ready": { malay: "Sedia disimpan", english: "Ready to save" },
  "dl.subtitle": { malay: "Tampal pautan, pilih, dan simpan ke arkib.", english: "Paste a link, choose your format, and save it to your archive." },
  // Common
  "common.video": { malay: "Video", english: "Video" },
  "common.audio": { malay: "Audio", english: "Audio" },
  "common.quality": { malay: "Kualiti", english: "Quality" },
  "common.format": { malay: "Format", english: "Format" },
  "common.clear": { malay: "Kosongkan", english: "Clear" },
  "common.best": { malay: "Terbaik", english: "Best" },
  "common.play": { malay: "Main", english: "Play" },
  "common.reveal": { malay: "Tunjuk di Explorer", english: "Reveal in Explorer" },
  "common.openLibrary": { malay: "Buka di Pustaka", english: "Open in Library" },
  "common.retry": { malay: "Cuba Semula", english: "Retry" },
  "common.loading": { malay: "Memuat…", english: "Loading…" },
  "common.saved": { malay: "Disimpan", english: "Saved" },
  "common.failed": { malay: "Gagal", english: "Failed" },
  "common.queued": { malay: "Dalam giliran…", english: "Queued…" },
  "common.finishing": { malay: "Menyiapkan…", english: "Finishing…" },
  "common.cancel": { malay: "Batal", english: "Cancel" },
  // Activity
  "activity.title": { malay: "Aktiviti", english: "Activity" },
  "activity.active": { malay: "Aktif", english: "Active" },
  "activity.history": { malay: "Sejarah", english: "History" },
  "activity.empty": { malay: "Tiada simpanan aktif", english: "No active saves" },
  "act.playInApp": { malay: "Main dalam app", english: "Play in app" },
  "act.edit": { malay: "Sunting video", english: "Edit video" },
  "act.reveal": { malay: "Cari di Explorer", english: "Find in Explorer" },
  "act.remove": { malay: "Buang dari sejarah", english: "Remove from history" },
  "act.retry": { malay: "Cuba semula", english: "Retry" },
  "act.clearHistory": { malay: "Kosongkan sejarah", english: "Clear history" },
  "act.clearNotice": {
    malay: "Sejarah dalam app akan dikosongkan. Fail teks laporan dalam folder Laporan kekal tersimpan.",
    english: "In-app history will be cleared. The report text files in the Report folder are kept.",
  },
  // Library
  "lib.folders": { malay: "Folder", english: "Folders" },
  "lib.media": { malay: "Media", english: "Media" },
  "lib.player": { malay: "Pemain", english: "Player" },
  "lib.editor": { malay: "Editor", english: "Editor" },
  "lib.search": { malay: "Cari tajuk, platform, kata kunci…", english: "Search titles, platforms, keywords…" },
  "lib.newFolder": { malay: "Folder Baharu", english: "New Folder" },
  "lib.selectAll": { malay: "Pilih Semua", english: "Select All" },
  "lib.all": { malay: "Semua", english: "All" },
  "lib.videos": { malay: "Video", english: "Videos" },
  "lib.notes": { malay: "Nota", english: "Notes" },
  "lib.allNotes": { malay: "Semua nota", english: "All notes" },
};

export function loc(key: string, lang: AppLanguage): string {
  return table[key]?.[lang] ?? table[key]?.english ?? key;
}

// --- Greetings (port of Greetings.swift) ---

const salamsMY = ["Hai", "Selamat pagi", "Apa khabar", "Salam", "Semekom", "Assalamualaikum", "Hello", "Wei", "Yo", "Eh"];
const salamsEN = ["Hi", "Hey", "Hello", "Yo", "Morning", "Sup", "Oi"];

const linesMY = [
  "Nak arkib apa hari ni?", "Nak arkib apa tu?", "Nak simpan video mana hari ni?", "Haaa, donlod apa?",
  "Apa nak curi hari ni? Curi ilmu je tau.", "Ada video best nak simpan?", "Jom simpan, jom arkib.",
  "Tampal je pautan tu, biar Musim uruskan.", "Nak video ke audio hari ni?", "Banyak mana nak simpan hari ni?",
  "Video viral tu jangan lupa simpan.", "Playlist dah backup ke belum?", "Sekali tampal, terus jadi.",
  "Ada lagu baru nak simpan?", "Koleksi video tak akan penuh sendiri tau.", "Apa cerita, lama tak arkib?",
  "Simpan dulu, tonton kemudian.", "On je, kita gas sampai 8K.", "Jom kemas pustaka video sikit.",
  "Content creator kegemaran dah upload baru tu.", "Nak arkib video sebelum ia hilang?",
  "Rehat sekejap, biar Musim yang kerja.", "Video panjang pun kacang je.", "Steady, tampal je pautan.",
  "Jangan segan, banyak pautan pun boleh.", "Backup itu tanda sayang.", "Satu hari satu video, sihat jiwa.",
  "Nak simpan reels ke shorts hari ni?", "Wei, ada video best tak nak kongsi kat sini?",
  "Percaya proses je — tampal, pilih, simpan.",
];

const linesEN = [
  "What are you archiving today?", "What are we saving today?", "Got a video to keep?",
  "Paste a link, I'll handle the rest.", "Video or audio today?", "How many are we grabbing today?",
  "That viral clip won't save itself.", "Backed up your playlist yet?", "One paste and it's done.",
  "New track to save?", "Your collection won't fill itself, you know.", "Long time no archive — what's good?",
  "Save now, watch later.", "Let's push it all the way to 8K.", "Time to tidy up the library a bit?",
  "Your favourite creator just posted.", "Archive it before it disappears.", "Take a break, let Musim do the work.",
  "Three-hour video? Easy.", "Steady lah, just paste the link.", "Don't be shy, multiple links work too.",
  "Backing up is caring.", "One video a day keeps the FOMO away.", "Saving a reel or a short today?",
  "Got a good clip to share here?", "Trust the process — paste, pick, save.",
];

const pick = <T,>(a: T[]): T => a[Math.floor(Math.random() * a.length)];

export function greeting(lang: AppLanguage, userName: string): string {
  const name = userName.trim() || (lang === "malay" ? "bos" : "there");
  const salam = pick(lang === "malay" ? salamsMY : salamsEN);
  const line = pick(lang === "malay" ? linesMY : linesEN);
  return `${salam}, ${name}. ${line}`;
}
