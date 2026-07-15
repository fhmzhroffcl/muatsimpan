import type { Metadata } from "next";
import "./globals.css";

const TAJUK = "Musim — Muat Turun Video dan Audio Percuma untuk Mac & Windows";
const HURAIAN =
  "Muat turun video dan audio yang disokong terus ke Mac atau Windows dengan Musim. Percuma selamanya, tanpa akaun dan tanpa langganan.";

export const metadata: Metadata = {
  title: TAJUK,
  description: HURAIAN,
  keywords: [
    "muat turun video Mac",
    "muat turun video Windows",
    "muat turun audio",
    "pemuat turun video",
    "Musim",
    "aplikasi muat turun percuma",
  ],
  robots: { index: true, follow: true },
  icons: { icon: "/musim-icon.png" },
  openGraph: {
    type: "website",
    locale: "ms_MY",
    siteName: "Musim",
    title: TAJUK,
    description: HURAIAN,
    images: ["/og-musim-v2.png"],
  },
  twitter: {
    card: "summary_large_image",
    title: "Musim untuk Mac & Windows",
    description: HURAIAN,
    images: ["/og-musim-v2.png"],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ms">
      <body>{children}</body>
    </html>
  );
}
