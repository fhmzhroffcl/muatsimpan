//! Rolling archive report — port of Sources/Musim/Engine/ReportLogger.swift.
//! Appends one tab-separated line per completed download to a text file whose
//! rollover (daily/weekly/monthly) follows the historyLog setting.

use crate::models::{DownloadItem, MediaType};
use crate::settings::{AppLanguage, AppSettings, HistoryLogFrequency};
use chrono::{Datelike, Local};
use std::path::PathBuf;

pub fn log(item: &DownloadItem, settings: &AppSettings, support_dir: &PathBuf) {
    if settings.history_log == HistoryLogFrequency::Never {
        return;
    }
    let malay = settings.language == AppLanguage::Malay;
    let dir = support_dir.join(if malay { "Laporan" } else { "Report" });
    let _ = std::fs::create_dir_all(&dir);

    let now = Local::now();
    let stamp = now.format("%Y-%m-%d %H:%M:%S").to_string();
    let kind = if item.media_type == MediaType::Video {
        "Video"
    } else {
        "Audio"
    };
    let path = item.saved_file_path.clone().unwrap_or_else(|| "-".into());
    let line = format!(
        "{stamp}\t{kind}\t{}\t{}\t{}\t{}\n",
        item.platform.label(),
        item.title,
        item.url,
        path
    );

    let file = dir.join(file_name(settings.history_log, &now));
    if file.exists() {
        use std::io::Write;
        if let Ok(mut f) = std::fs::OpenOptions::new().append(true).open(&file) {
            let _ = f.write_all(line.as_bytes());
        }
    } else {
        let header = if malay {
            format!(
                "Musim — Laporan arkib ({:?})\nMasa\tJenis\tPlatform\tTajuk\tPautan\tDisimpan di\n",
                settings.history_log
            )
        } else {
            format!(
                "Musim — Archive report ({:?})\nWhen\tType\tPlatform\tTitle\tLink\tSaved to\n",
                settings.history_log
            )
        };
        let _ = std::fs::write(&file, format!("{header}{line}"));
    }
}

fn file_name(freq: HistoryLogFrequency, now: &chrono::DateTime<Local>) -> String {
    let tag = match freq {
        HistoryLogFrequency::Daily | HistoryLogFrequency::Never => now.format("%Y-%m-%d").to_string(),
        HistoryLogFrequency::Weekly => format!("{}-W{:02}", now.iso_week().year(), now.iso_week().week()),
        HistoryLogFrequency::Monthly => now.format("%Y-%m").to_string(),
    };
    format!("musim-{tag}.txt")
}
