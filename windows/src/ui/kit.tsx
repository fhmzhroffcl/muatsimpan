// Shared building blocks: logo, glass card, buttons, modal, chips, spinner,
// and the subtle Malaysian pattern overlay.

import { type CSSProperties, type ReactNode, useEffect } from "react";
import logoUrl from "../assets/logo.png";
import { Icon } from "./Icon";
import { patternDataUri, type PatternStyle } from "../lib/theme";

export function Logo({ size = 40 }: { size?: number }) {
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.28,
        background: "#000",
        display: "grid",
        placeItems: "center",
        boxShadow: `0 ${size * 0.04}px ${size * 0.1}px rgba(0,0,0,.25)`,
        flexShrink: 0,
      }}
    >
      <img src={logoUrl} alt="Musim" style={{ width: "76%", height: "76%", objectFit: "contain" }} />
    </div>
  );
}

export function GlassCard({
  children,
  glow = false,
  radius = 12,
  style,
  className,
  ...rest
}: {
  children: ReactNode;
  glow?: boolean;
  radius?: number;
  style?: CSSProperties;
  className?: string;
} & React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`glass-card ${className ?? ""}`}
      style={{
        borderRadius: radius,
        borderColor: glow ? "var(--accent)" : undefined,
        ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}

type BtnProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "glass";
  icon?: string;
};

export function Btn({ variant = "glass", icon, children, className, ...rest }: BtnProps) {
  return (
    <button className={`${variant === "primary" ? "btn-primary" : "btn-glass"} ${className ?? ""}`} {...rest}>
      <span style={{ display: "inline-flex", alignItems: "center", gap: 7 }}>
        {icon && <Icon name={icon} size={15} />}
        {children}
      </span>
    </button>
  );
}

export function IconButton({
  icon,
  size = 34,
  active = false,
  title,
  onClick,
  style,
}: {
  icon: string;
  size?: number;
  active?: boolean;
  title?: string;
  onClick?: () => void;
  style?: CSSProperties;
}) {
  return (
    <button
      title={title}
      onClick={onClick}
      className="icon-btn"
      style={{
        width: size,
        height: size,
        color: active ? "#fff" : "var(--text-secondary)",
        background: active ? "linear-gradient(135deg,var(--accent),var(--accent2))" : "transparent",
        ...style,
      }}
    >
      <Icon name={icon} size={size * 0.46} />
    </button>
  );
}

export function Spinner({ size = 18 }: { size?: number }) {
  return (
    <span
      className="spinner"
      style={{ width: size, height: size, borderWidth: Math.max(2, size / 9) }}
      aria-label="loading"
    />
  );
}

export function Modal({ onClose, width = 520, children }: { onClose: () => void; width?: number; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-card"
        style={{ width }}
        onClick={(e) => e.stopPropagation()}
      >
        {children}
      </div>
    </div>
  );
}

export function Chip({
  children,
  active = false,
  onClick,
  style,
}: {
  children: ReactNode;
  active?: boolean;
  onClick?: () => void;
  style?: CSSProperties;
}) {
  return (
    <span
      onClick={onClick}
      className="chip"
      style={{
        cursor: onClick ? "pointer" : "default",
        color: active ? "#fff" : "var(--text-secondary)",
        background: active ? "linear-gradient(135deg,var(--accent),var(--accent2))" : "var(--surface-hover)",
        borderColor: active ? "transparent" : "var(--border)",
        ...style,
      }}
    >
      {children}
    </span>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { id: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="segmented">
      {options.map((o) => (
        <button
          key={o.id}
          className={value === o.id ? "seg-active" : ""}
          onClick={() => onChange(o.id)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

// Subtle tiling pattern overlay following the user's setting.
export function PatternBg({
  pattern,
  accentHex,
  opacity = 0.06,
  radius,
}: {
  pattern: PatternStyle;
  accentHex: string;
  opacity?: number;
  radius?: number;
}) {
  const uri = patternDataUri(pattern, accentHex, opacity);
  if (!uri) return null;
  return (
    <div
      aria-hidden
      style={{
        position: "absolute",
        inset: 0,
        backgroundImage: uri,
        backgroundRepeat: "repeat",
        pointerEvents: "none",
        borderRadius: radius,
      }}
    />
  );
}
