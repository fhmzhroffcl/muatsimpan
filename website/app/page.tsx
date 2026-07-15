"use client";

import { useEffect, useState } from "react";

// Butiran keluaran am.
const KELUARAN = {
  macos: "14",
  seniBina: "Apple Silicon",
  namaPenerima: "Fahim Zahar",
};

// Senarai keluaran — tambah entri baharu di bahagian ATAS bila keluar versi baru.
// `semasa: true` menandakan versi terkini (boleh dimuat turun). Versi lama dikelabukan.
const VERSI = [
  {
    versi: "2.0",
    tarikh: "2026-07-15",
    semasa: true,
    nota: [
      "Keluaran terkini Musim untuk macOS.",
      "Ganti baris ini dengan perubahan sebenar keluaran v2.",
    ],
    mac: "https://drive.google.com/file/d/1LNDR8LyN5EO0b6sqhGfVG8IC3PcIt14r/view?usp=share_link",
    macSaiz: "",
  },
  {
    versi: "1.0",
    tarikh: "2026-07-10",
    semasa: false,
    nota: ["Keluaran awam pertama Musim untuk macOS."],
    mac: "https://drive.google.com/file/d/1jMEInmSaU_TSrPbDmDiJp7IxDSRKtkke/view?usp=share_link",
    macSaiz: "145.8 MB",
  },
];

const TERKINI = VERSI.find((v) => v.semasa) ?? VERSI[0];
const META = `Versi ${TERKINI.versi} · macOS ${KELUARAN.macos}+ · ${KELUARAN.seniBina}`;

function ButangWindows({ className = "" }: { className?: string }) {
  return (
    <span
      className={`butang tidak-aktif ${className}`}
      role="button"
      aria-disabled="true"
      title="Windows akan datang"
    >
      Windows · Akan datang
    </span>
  );
}

function ButangMac({ label, className = "butang utama" }: { label: string; className?: string }) {
  return (
    <a className={className} href={TERKINI.mac} target="_blank" rel="noopener noreferrer">
      {label}
    </a>
  );
}

export default function Home() {
  const [menu, setMenu] = useState(false);
  const [domain, setDomain] = useState("fail setempat projek ini");

  useEffect(() => {
    if (typeof window !== "undefined" && window.location.host) {
      setDomain(window.location.host);
    }
  }, []);

  useEffect(() => {
    const io = new IntersectionObserver(
      (entries) =>
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("muncul");
            io.unobserve(entry.target);
          }
        }),
      { threshold: 0.12 }
    );
    document.querySelectorAll(".dedah").forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);

  const skema = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Musim",
    description:
      "Aplikasi percuma untuk menyimpan video dan audio yang disokong terus ke Mac. Sokongan Windows akan datang.",
    applicationCategory: "MultimediaApplication",
    operatingSystem: `macOS ${KELUARAN.macos} atau lebih baharu`,
    softwareVersion: TERKINI.versi,
    datePublished: TERKINI.tarikh,
    downloadUrl: TERKINI.mac,
    offers: { "@type": "Offer", price: "0", priceCurrency: "MYR" },
    isBasedOn: "https://github.com/nexmoe/VidBee",
    license: "https://opensource.org/license/mit",
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(skema) }}
      />
      <a className="langkau" href="#kandungan">
        Langkau ke kandungan utama
      </a>

      <nav aria-label="Navigasi utama">
        <div className="bekas bar-nav">
          <a className="jenama" href="#atas">
            <img src="/musim-icon.png" alt="" width={36} height={36} />
            <span>Musim</span>
          </a>
          <button
            className="menu"
            aria-expanded={menu}
            aria-controls="pautan-nav"
            aria-label="Buka menu"
            onClick={() => setMenu((v) => !v)}
          >
            ☰
          </button>
          <div className={`pautan-nav${menu ? " buka" : ""}`} id="pautan-nav" onClick={() => setMenu(false)}>
            <a href="#ciri">Ciri</a>
            <a href="#cara">Cara guna</a>
            <a href="#log">Log perubahan</a>
            <a href="#soalan">Soalan lazim</a>
          </div>
          <div className="tindakan-nav">
            <a className="pautan-teks" href="#sumber">
              Kod sumber
            </a>
            <ButangMac label="Muat turun untuk Mac" className="butang utama kecil" />
            <ButangWindows className="kecil" />
          </div>
        </div>
      </nav>

      <main id="kandungan">
        <header id="atas">
          <div className="bekas hero-grid">
            <div className="hero">
              <p className="prajudul">Pemuat turun video percuma untuk Mac</p>
              <h1>Muat turun video tanpa iklan, akaun atau langganan.</h1>
              <p>
                Musim ialah aplikasi percuma untuk menyimpan video dan audio yang
                disokong terus ke Mac anda—tanpa akaun, dengan sumbangan pilihan
                sahaja. Versi Windows akan datang.
              </p>
              <div className="butang-baris">
                <ButangMac label="Muat turun untuk Mac" />
                <ButangWindows />
              </div>
              <div className="mikro">
                Percuma selamanya · Tanpa akaun · Sumbangan pilihan
              </div>
              <div className="metadata">{META}</div>
            </div>
            <div>
              <div className="bingkai">
                <video
                  src="/aliran-url.mp4"
                  autoPlay
                  muted
                  loop
                  playsInline
                  aria-label="Rakaman sebenar aliran muat turun dalam Musim"
                />
              </div>
              <div className="domain">
                Destinasi muat turun: <span>{domain}</span>
              </div>
            </div>
          </div>
        </header>

        <div className="jalur-amanah">
          <div className="bekas amanah-grid">
            <div className="amanah">
              <span className="ikon">✓</span>
              <div>
                <strong>Percuma selamanya</strong>
                <span>Semua ciri disertakan.</span>
              </div>
            </div>
            <div className="amanah">
              <span className="ikon">○</span>
              <div>
                <strong>Tanpa akaun</strong>
                <span>Tiada pendaftaran.</span>
              </div>
            </div>
            <div className="amanah">
              <span className="ikon">↓</span>
              <div>
                <strong>Simpanan setempat</strong>
                <span>Terus ke folder pilihan anda.</span>
              </div>
            </div>
            <div className="amanah">
              <span className="ikon">⌘</span>
              <div>
                <strong>Asas sumber terbuka</strong>
                <span>Dibina dengan alat yang terbukti.</span>
              </div>
            </div>
          </div>
        </div>

        <section id="cara">
          <div className="bekas">
            <div className="tajuk-seksyen dedah">
              <h2>Tampal. Pilih. Simpan.</h2>
            </div>
            <div className="langkah dedah">
              <article>
                <div className="nombor">01</div>
                <h3>Tampal pautan</h3>
                <p>Masukkan alamat media yang disokong.</p>
              </article>
              <article>
                <div className="nombor">02</div>
                <h3>Pilih versi anda</h3>
                <p>Pilih mutu, format atau pilihan audio yang tersedia.</p>
              </article>
              <article>
                <div className="nombor">03</div>
                <h3>Simpan secara setempat</h3>
                <p>Muat turun terus ke folder pilihan pada Mac anda.</p>
              </article>
            </div>
          </div>
        </section>

        <section id="ciri">
          <div className="bekas">
            <div className="tajuk-seksyen dedah">
              <h2>Semua yang anda perlukan untuk menyimpan media secara setempat.</h2>
            </div>
            <div className="hasil">
              <article className="dedah">
                <div className="media">
                  <video src="/aliran-url.mp4" muted loop playsInline controls preload="none" />
                </div>
                <div className="salinan">
                  <h3>Muat turun video dan audio</h3>
                  <p>
                    Simpan video yang disokong untuk tontonan, rujukan atau arkib
                    kandungan yang dibenarkan. Ambil audio yang tersedia tanpa
                    penukar berasingan atau memuat naik fail ke perkhidmatan lain.
                  </p>
                </div>
              </article>
              <article className="dedah">
                <div className="media">
                  <video src="/kemajuan.mp4" muted loop playsInline controls preload="none" />
                </div>
                <div className="salinan">
                  <h3>Pilihan mutu dan pengurusan muat turun</h3>
                  <p>
                    Pilih mutu serta format sebelum muat turun bermula. Pantau
                    beberapa muat turun dan cuba semula jika berlaku gangguan.
                  </p>
                </div>
              </article>
              <article className="dedah">
                <div className="media">
                  <video src="/pustaka.mp4" muted loop playsInline controls preload="none" />
                </div>
                <div className="salinan">
                  <h3>Pustaka muat turun</h3>
                  <p>
                    Cari fail siap dengan pantas, susun media ke dalam folder dan
                    buka terus dalam Finder.
                  </p>
                </div>
              </article>
              <article className="dedah">
                <div className="media">
                  <video src="/editor.mp4" muted loop playsInline controls preload="none" />
                </div>
                <div className="salinan">
                  <h3>Penyediaan video pantas</h3>
                  <p>
                    Potong, krop, laraskan kelajuan, nisbah atau peleraian video
                    sedia ada sebelum mengeksportnya.
                  </p>
                </div>
              </article>
            </div>
          </div>
        </section>

        <section className="gelap" id="privasi">
          <div className="bekas privasi-grid">
            <div className="tajuk-seksyen dedah">
              <h2>Apa yang anda simpan kekal dalam kawalan anda.</h2>
              <p>
                Musim tidak mengendalikan pustaka media dalam talian. Data aplikasi
                dan fail muat turun disimpan pada Mac anda.
              </p>
              <p>
                <a className="pautan-teks" href="/privacy.md">
                  Baca butiran privasi →
                </a>
              </p>
            </div>
            <div className="senarai-semak dedah">
              <div className="semak">
                <i>✓</i>
                <div>
                  <strong>Tiada akaun Musim</strong>
                  <span>
                    Tiada pendaftaran, analitik, telemetri atau laporan ranap
                    dihantar kepada pembangun.
                  </span>
                </div>
              </div>
              <div className="semak">
                <i>✓</i>
                <div>
                  <strong>Folder pilihan anda</strong>
                  <span>Video, audio, sejarah dan tetapan kekal secara setempat.</span>
                </div>
              </div>
              <div className="semak">
                <i>✓</i>
                <div>
                  <strong>Sambungan rangkaian yang dinyatakan</strong>
                  <span>
                    Musim menghubungi sumber media apabila anda meminta muat turun
                    dan GitHub untuk mendapatkan kemas kini enjin yt-dlp. Kuki
                    pelayar, jika dihidupkan, dihantar terus kepada platform sumber
                    sahaja.
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="log">
          <div className="bekas">
            <div className="tajuk-seksyen dedah">
              <h2>Log perubahan &amp; muat turun</h2>
              <p>
                Setiap keluaran Musim disenaraikan di bawah. Hanya versi terkini
                boleh dimuat turun; versi lama dikekalkan sebagai rujukan sahaja.
              </p>
            </div>
            <div className="log-senarai dedah">
              {VERSI.map((v) => (
                <article key={v.versi} className={`keluaran${v.semasa ? "" : " lama"}`}>
                  <div className="keluaran-tajuk">
                    <h3>Musim {v.versi}</h3>
                    <span className="keluaran-tarikh">{v.tarikh}</span>
                    <span className={`lencana ${v.semasa ? "baru" : "usang"}`}>
                      {v.semasa ? "Versi terkini" : "Versi lama"}
                    </span>
                  </div>
                  <ul className="keluaran-nota">
                    {v.nota.map((n, i) => (
                      <li key={i}>{n}</li>
                    ))}
                  </ul>
                  <div className="keluaran-fail">
                    <div className="fail">
                      <div className="fail-info">
                        <span className="fail-platform">macOS · Apple Silicon</span>
                        {v.macSaiz && <span className="fail-saiz">{v.macSaiz}</span>}
                      </div>
                      {v.semasa ? (
                        <a
                          className="butang utama kecil"
                          href={v.mac}
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          Muat turun
                        </a>
                      ) : (
                        <span className="butang kecil tidak-aktif" aria-disabled="true">
                          Tidak tersedia
                        </span>
                      )}
                    </div>
                    <div className="fail">
                      <div className="fail-info">
                        <span className="fail-platform">Windows</span>
                      </div>
                      <span className="butang kecil tidak-aktif" aria-disabled="true">
                        Akan datang
                      </span>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section>
          <div className="bekas terbuka-grid">
            <div className="tajuk-seksyen dedah">
              <h2>Percuma bermaksud seluruh aplikasi.</h2>
              <p>
                Menderma tidak membuka ciri tambahan. Ia sekadar membantu Musim
                terus diselenggara.
              </p>
            </div>
            <table className="jadual dedah">
              <tbody>
                <tr>
                  <th>Seluruh aplikasi</th>
                  <td>RM0</td>
                </tr>
                <tr>
                  <th>Muat turun</th>
                  <td>Tanpa had oleh Musim</td>
                </tr>
                <tr>
                  <th>Akaun</th>
                  <td>Tidak diperlukan</td>
                </tr>
                <tr>
                  <th>Langganan</th>
                  <td>Tiada</td>
                </tr>
                <tr>
                  <th>Kemas kini</th>
                  <td>Percuma</td>
                </tr>
                <tr>
                  <th>Sumbangan</th>
                  <td>Pilihan</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section id="sumber">
          <div className="bekas terbuka-grid">
            <div className="tajuk-seksyen dedah">
              <h2>Dibina secara terbuka, dengan penghargaan kepada pemiliknya.</h2>
              <p>
                Musim diinspirasikan oleh VidBee dan dikuasakan oleh yt-dlp serta
                FFmpeg. Projek sumber terbuka ini menyediakan asas; Musim membina
                semula pengalaman dalam SwiftUI untuk aliran kerja macOS tersendiri.
              </p>
              <p className="nota">
                Musim tidak mendakwa mencipta VidBee, yt-dlp atau FFmpeg. Hak cipta
                dan lesen setiap projek kekal milik pemegangnya.
              </p>
            </div>
            <div className="pautan-sumber dedah">
              <span className="belum">
                Kod sumber Musim <b>Belum diterbitkan</b>
              </span>
              <a href="https://github.com/nexmoe/VidBee" rel="noopener">
                VidBee <b>↗</b>
              </a>
              <a href="https://github.com/yt-dlp/yt-dlp" rel="noopener">
                yt-dlp <b>↗</b>
              </a>
              <a href="https://ffmpeg.org/" rel="noopener">
                FFmpeg <b>↗</b>
              </a>
              <a href="https://opensource.org/license/mit" rel="noopener">
                Lesen MIT <b>↗</b>
              </a>
              <a href="#log">
                Nota keluaran <b>↗</b>
              </a>
            </div>
          </div>
        </section>

        <section id="soalan">
          <div className="bekas">
            <div className="tajuk-seksyen dedah">
              <h2>Soalan lazim</h2>
            </div>
            <div className="soalan dedah">
              <details>
                <summary>Adakah Musim benar-benar percuma?</summary>
                <p>
                  Ya. Seluruh aplikasi, muat turun dan kemas kini adalah percuma.
                  Sumbangan tidak membuka apa-apa ciri.
                </p>
              </details>
              <details>
                <summary>Bilakah versi Windows akan keluar?</summary>
                <p>
                  Versi Windows sedang dalam pembangunan. Butang Windows akan aktif
                  di laman ini sebaik sahaja binaan tersedia untuk dimuat turun.
                </p>
              </details>
              <details>
                <summary>Adakah pemasang ini selamat?</summary>
                <p>
                  Pemasang yang dipautkan ialah binaan Musim rasmi. Musim belum
                  ditentusahkan oleh Apple, jadi macOS mungkin menunjukkan amaran.
                </p>
              </details>
              <details>
                <summary>Bolehkah saya memuat turun versi lama?</summary>
                <p>
                  Tidak. Hanya versi terkini boleh dimuat turun. Versi lama
                  disenaraikan dalam log perubahan sebagai rujukan sahaja dan
                  dikelabukan.
                </p>
              </details>
              <details>
                <summary>Model Mac manakah yang disokong?</summary>
                <p>
                  Binaan ini menyokong Mac Apple Silicon yang menjalankan macOS 14
                  atau lebih baharu. Mac berasaskan Intel belum disokong.
                </p>
              </details>
              <details>
                <summary>Adakah Musim berfungsi dengan setiap laman?</summary>
                <p>
                  Tidak. Sokongan bergantung pada yt-dlp dan perubahan platform.
                  Sesebuah laman mungkin berhenti berfungsi buat sementara waktu
                  sehingga enjin dikemas kini.
                </p>
              </details>
              <details>
                <summary>Di manakah muat turun saya disimpan?</summary>
                <p>
                  Dalam folder yang anda pilih. Sejarah dan susun atur pustaka
                  disimpan dalam folder Sokongan Aplikasi Musim pada Mac anda.
                </p>
              </details>
              <details>
                <summary>Adakah Musim mengumpul data?</summary>
                <p>
                  Tidak. Binaan semasa tiada analitik, telemetri atau laporan ranap.
                  Musim hanya membuat sambungan rangkaian yang diterangkan dalam
                  bahagian privasi.
                </p>
              </details>
              <details>
                <summary>Bolehkah saya memuat turun video berhak cipta?</summary>
                <p>
                  Hanya muat turun kandungan milik anda, yang dibenarkan pemiliknya,
                  berlesen sesuai atau yang anda diberi kuasa secara sah untuk simpan.
                </p>
              </details>
              <details>
                <summary>Apakah yang dibiayai oleh sumbangan?</summary>
                <p>
                  Pembangunan, ujian, tandatangan aplikasi dan pengehosan. Aplikasi
                  tetap lengkap jika anda tidak menderma.
                </p>
              </details>
            </div>
          </div>
        </section>

        <section className="sumbangan" id="sumbangan">
          <div className="bekas sumbang-grid">
            <div className="tajuk-seksyen dedah">
              <h2>Musim percuma. Mengekalkannya tetap memerlukan usaha.</h2>
              <p>
                Jika Musim menjimatkan masa anda, sumbangan boleh membantu kos
                pembangunan, ujian, tandatangan dan pengehosan. Apa-apa jumlah
                membantu, tetapi tiada apa yang berubah jika anda tidak
                menderma—seluruh aplikasi kekal percuma.
              </p>
              <div className="pilihan">
                <span>RM5</span>
                <span>RM10</span>
                <span>RM20</span>
              </div>
              <a className="butang" href="#akhir">
                Bukan sekarang—teruskan memuat turun
              </a>
            </div>
            <div className="kad-qr dedah">
              <img
                src="/duitnow.png"
                loading="lazy"
                width={190}
                height={190}
                alt="Kod QR DuitNow untuk menyokong Musim"
              />
              <div>
                <h3>Sumbang melalui DuitNow</h3>
                <p className="penerima">
                  Nama penerima: <span>{KELUARAN.namaPenerima}</span>
                </p>
                <p className="suram">
                  Sumbangan adalah pilihan dan tidak membuka ciri. Sahkan nama
                  penerima dalam aplikasi bank anda sebelum mengesahkan.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="akhir" id="akhir">
          <div className="akhir-grid">
            <div>
              <h2>Simpan apa yang anda perlukan selagi ia masih tersedia.</h2>
              <p>
                Muat turun aplikasi Musim lengkap untuk macOS tanpa akaun,
                langganan atau peningkatan berbayar. Versi Windows akan datang.
              </p>
              <div className="metadata">{META}</div>
            </div>
            <div>
              <div className="butang-baris">
                <ButangMac label="Muat turun untuk Mac" />
                <ButangWindows />
              </div>
              <p className="mikro">
                Percuma selamanya · Sumbangan pilihan · Sumber dan lesen tersedia
              </p>
            </div>
          </div>
        </section>
      </main>

      <footer>
        <div className="bekas">
          <div className="kaki-grid">
            <a className="jenama" href="#atas">
              <img src="/musim-icon.png" alt="" width={36} height={36} />
              <span>Musim</span>
            </a>
            <div className="pautan-kaki">
              <a href={TERKINI.mac} target="_blank" rel="noopener noreferrer">
                Muat turun Mac
              </a>
              <span className="kaki-mati">Windows · Akan datang</span>
              <a href="#log">Log perubahan</a>
              <a href="#sumber">Kod sumber</a>
              <a href="#soalan">Laporkan masalah</a>
              <a href="/privacy.md">Privasi</a>
              <a href="https://opensource.org/license/mit">Lesen</a>
              <a href="/terms.md">Notis penggunaan sah</a>
            </div>
          </div>
          <p className="undang">
            Musim bertujuan untuk memuat turun kandungan milik anda, kandungan yang
            anda diberi kebenaran untuk gunakan, atau kandungan yang anda dibenarkan
            secara sah untuk simpan. Pengguna bertanggungjawab mematuhi undang-undang
            dan syarat platform yang berkenaan.
          </p>
          <p className="undang">© 2026 Musim. Dibangunkan di Malaysia.</p>
        </div>
      </footer>
    </>
  );
}
