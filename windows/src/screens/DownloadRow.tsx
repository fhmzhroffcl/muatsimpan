import { api, type DownloadItem } from "../api";
import { useApp } from "../lib/store";
import { GlassCard, Chip, IconButton } from "../ui/kit";
import { Icon } from "../ui/Icon";
import { Thumbnail } from "../ui/Thumbnail";
import { bytes } from "../lib/format";

// Active/finished queue row on the archive page.
export function DownloadRow({ item, faded = false }: { item: DownloadItem; faded?: boolean }) {
  const { t } = useApp();
  const size = item.fileSize ?? item.estimatedSize;

  return (
    <GlassCard radius={12} style={{ padding: 12, opacity: faded ? 0.62 : 1 }}>
      <div style={{ display: "flex", gap: 14, alignItems: "center" }}>
        <Thumbnail src={item.thumbnailUrl} platform={item.platform} width={128} height={74} />
        <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 5 }}>
          <div style={{ fontSize: 14, fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{item.title}</div>
          {(item.channel || item.uploader) && (
            <div style={{ fontSize: 12, color: "var(--text-secondary)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{item.channel || item.uploader}</div>
          )}
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            <Chip>{item.type === "video" ? t("common.video") : t("common.audio")}</Chip>
            {(item.qualityLabel || item.formatNote) && <Chip>{item.qualityLabel || item.formatNote}</Chip>}
            {item.ext && <Chip>{item.ext.toUpperCase()}</Chip>}
            {size ? <Chip>{bytes(size)}</Chip> : null}
          </div>
          <Progress item={item} />
        </div>
        <Actions item={item} />
      </div>
    </GlassCard>
  );
}

function Progress({ item }: { item: DownloadItem }) {
  const { t } = useApp();
  if (item.status === "downloading") {
    const pct = Math.min(item.progress.percent, 100);
    return (
      <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
        <div style={{ height: 6, background: "var(--border)", borderRadius: 999 }}>
          <div style={{ width: `${Math.max(6, pct)}%`, height: "100%", borderRadius: 999, background: "var(--accent)", transition: "width .2s" }} />
        </div>
        <div style={{ display: "flex", gap: 8, fontSize: 10, color: "var(--text-secondary)", fontVariantNumeric: "tabular-nums" }}>
          <span>{item.progress.percent.toFixed(1)}%</span>
          {item.progress.speed && <span>{item.progress.speed}</span>}
          {item.progress.eta && <span>ETA {item.progress.eta}</span>}
        </div>
      </div>
    );
  }
  if (item.status === "processing")
    return <span style={{ fontSize: 12, color: "var(--text-secondary)" }}>{t("common.finishing")}</span>;
  if (item.status === "pending")
    return <span style={{ fontSize: 12, color: "var(--text-secondary)" }}>{t("common.queued")}</span>;
  if (item.status === "completed")
    return (
      <div style={{ display: "flex", gap: 8, alignItems: "center", fontSize: 12, color: "var(--text-secondary)" }}>
        <Icon name="check" size={13} style={{ color: "#4ade80" }} />
        {t("common.saved")}
        {item.savedFilePath && (
          <>
            <IconButton icon="play" size={24} title={t("common.play")} onClick={() => api.openPath(item.savedFilePath!)} />
            <IconButton icon="search" size={24} title={t("common.reveal")} onClick={() => api.revealInExplorer(item.savedFilePath!)} />
          </>
        )}
      </div>
    );
  if (item.status === "error")
    return <span style={{ fontSize: 12, color: "#f87171", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{item.errorMessage || t("common.failed")}</span>;
  return null;
}

function Actions({ item }: { item: DownloadItem }) {
  const active = ["pending", "downloading", "processing"].includes(item.status);
  return (
    <div style={{ display: "flex", gap: 6 }}>
      {(item.status === "error" || item.status === "cancelled") && <IconButton icon="refresh" onClick={() => api.retryDownload(item.id)} />}
      {active && <IconButton icon="x" onClick={() => api.cancelDownload(item.id)} />}
    </div>
  );
}
