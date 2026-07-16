import { fileSrc } from "../api";
import { Modal, Btn } from "../ui/kit";

// Video/audio playback modal — replaces the AVKit MiniPlayerView.
export function MiniPlayer({ path, title, onClose }: { path: string; title: string; onClose: () => void }) {
  const isAudio = /\.(mp3|m4a|wav|flac|opus|ogg)$/i.test(path);
  const src = fileSrc(path);
  return (
    <Modal onClose={onClose} width={680}>
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {isAudio ? (
          <audio src={src} controls autoPlay style={{ width: "100%" }} />
        ) : (
          <video src={src} controls autoPlay style={{ width: "100%", borderRadius: 10, background: "#000", aspectRatio: "16 / 9" }} />
        )}
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ flex: 1, fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{title}</div>
          <Btn onClick={onClose}>Close</Btn>
        </div>
      </div>
    </Modal>
  );
}
