# Musim motion design system

## Source grounding

This video is built from the SwiftUI source in `../Sources/Musim/Views/`.
It reproduces the app's dark appearance and its default `Senja` accent.

## Style prompt

Native macOS product motion: warm OLED-black canvas, restrained glass surfaces,
and the Musim Senja orange-to-red action gradient. The app window is the hero;
motion explains existing behaviour with deliberate camera focus, rather than
adding a parallel visual system. Use calm focus-pull crossfades, a precise
cursor, and the springs documented in Musim's `Theme`.

## Colors

- `#0B0B0C` app background
- `#151518` elevated/sidebar surface
- `#1C1C20` card surface
- `#2B2B31` border
- `#F2F1EE` primary text
- `#9A9A95` secondary text
- `#F1592A` Senja accent
- `#E23A2E` Senja gradient partner

## Typography

Use the macOS system stack (`-apple-system`, `BlinkMacSystemFont`, `Helvetica Neue`, sans-serif), matching SwiftUI's `.system` font.

## Geometry and motion

Use 9px, 12px, and 16px continuous-corner equivalents; cards have the source's
subtle 10px/4px shadow. Action controls use the Senja gradient. UI response is
fast (150–300ms), panel changes are 400–700ms, and camera moves are 600–1000ms.

## What NOT to do

- Do not introduce blue gradients, generic SaaS cards, glass bubbles, or new navigation.
- Do not use perspective, rotation, whip pans, continuous camera drift, or flashy particles.
- Do not add features unavailable in Download, Activity, Library, or Editor.
- Do not cover source UI with long copy; external callouts stay short and peripheral.
