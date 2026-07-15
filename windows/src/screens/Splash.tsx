import { useEffect, useRef } from "react";
import splashUrl from "../assets/splash.mp4";
import { Logo } from "../ui/kit";

// Plays the brand logo-reveal video, then hands off. Hard-capped so it never hangs.
export function Splash({ onFinished }: { onFinished: () => void }) {
  const done = useRef(false);
  const finish = () => {
    if (done.current) return;
    done.current = true;
    onFinished();
  };

  useEffect(() => {
    const cap = window.setTimeout(finish, 6000);
    return () => window.clearTimeout(cap);
  }, []);

  return (
    <div style={{ position: "fixed", inset: 0, background: "#000", display: "grid", placeItems: "center" }}>
      <video
        src={splashUrl}
        autoPlay
        muted
        playsInline
        onEnded={finish}
        onError={finish}
        style={{ width: "100%", height: "100%", objectFit: "contain" }}
      />
      <div style={{ position: "absolute", opacity: 0 }}>
        <Logo size={96} />
      </div>
    </div>
  );
}
