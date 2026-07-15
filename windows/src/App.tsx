import { useEffect, useState } from "react";
import { api, type AppSettings } from "./api";
import { applyTheme } from "./lib/theme";
import { AppProvider, useApp } from "./lib/store";
import { Splash } from "./screens/Splash";
import { Onboarding } from "./screens/Onboarding";
import { MainLayout } from "./screens/MainLayout";

export default function App() {
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [showSplash, setShowSplash] = useState(true);

  useEffect(() => {
    api.getSettings().then((s) => {
      applyTheme(s);
      setSettings(s);
      // Kick off engine check/install in the background on first launch.
      api.engineReady().then((ready) => {
        if (!ready) api.installEngine().catch(() => {});
      });
    });
  }, []);

  if (!settings) return <div style={{ position: "fixed", inset: 0, background: "var(--bg)" }} />;
  if (showSplash) return <Splash onFinished={() => setShowSplash(false)} />;

  return (
    <AppProvider settings={settings}>
      <Root />
    </AppProvider>
  );
}

// Inside the provider so onboarding completion (provider state) flips the view.
function Root() {
  const { settings } = useApp();
  return settings.onboardingCompleted ? <MainLayout /> : <Onboarding />;
}
