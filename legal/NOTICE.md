# Penghargaan & Lesen / Acknowledgements & Licenses

**Musim (Muat + Simpan) v2.0**

Musim dibina di atas perisian sumber terbuka. Kami tidak mendakwa mencipta mana-mana projek di bawah — hak cipta dan lesen setiap satu kekal milik pemegangnya masing-masing. / Musim is built on open-source software. We do not claim to have created any of the projects below — each one's copyright and license remain with its respective holders.

---

## VidBee — MIT License

Musim ialah aplikasi baharu yang dibina semula dalam SwiftUI, tetapi diinspirasikan oleh VidBee dan menggunakan sebahagian logik hujah yt-dlp yang diadaptasi daripadanya. / Musim is a new app rebuilt in SwiftUI, but it is inspired by VidBee and adapts part of its yt-dlp argument logic.

Source: https://github.com/nexmoe/VidBee

```
MIT License

Copyright (c) VidBee contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## yt-dlp — The Unlicense (Public Domain)

Enjin muat turun teras. / The core download engine.

Source: https://github.com/yt-dlp/yt-dlp

yt-dlp is released into the public domain under The Unlicense. No attribution is required, but it is gratefully given here.

---

## Deno — MIT License

Runtime JavaScript yang membantu yt-dlp menyelesaikan cabaran JS platform tertentu. / The JavaScript runtime that helps yt-dlp solve certain platforms' JS challenges.

Source: https://github.com/denoland/deno

```
MIT License

Copyright 2018-2024 the Deno authors

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the above copyright notice and this permission notice being included
in all copies or substantial portions of the Software.
```

---

## FFmpeg — GNU General Public License v3

Musim menggabung dan menukar media menggunakan FFmpeg. / Musim merges and converts media using FFmpeg.

Source: https://ffmpeg.org · https://github.com/FFmpeg/FFmpeg

**Penting / Important:** The specific FFmpeg build bundled with this copy of Musim is licensed under the **GNU General Public License, version 3 (GPLv3)**, because it was compiled with `--enable-gpl --enable-version3` and GPL-licensed libraries (including libx264 and libx265). This means the whole FFmpeg binary is covered by the GPLv3.

**Written offer of source code / Tawaran bertulis untuk kod sumber:**

The bundled binary is **FFmpeg version 8.1.2** (a precompiled build from https://www.martin-riedl.de). Its complete corresponding source code is publicly available from the official FFmpeg repository at https://github.com/FFmpeg/FFmpeg (tag `n8.1.2`) and https://ffmpeg.org/download.html.

The exact build configuration is:

```
--pkg-config-flags=--static --extra-version='https://www.martin-riedl.de'
--enable-gray --enable-libxml2 --enable-version3 --enable-gpl --enable-openssl
--enable-libfreetype --enable-fontconfig --enable-libharfbuzz --enable-libsnappy
--enable-libsrt --enable-libvmaf --enable-libass --enable-libklvanc --enable-libzimg
--enable-libzvbi --enable-libaom --enable-libdav1d --enable-libopenh264
--enable-libopenjpeg --enable-librav1e --enable-libsvtav1 --enable-libvpx
--enable-libvvenc --enable-libwebp --enable-libx264 --enable-libx265
--enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libtheora
```

For at least three (3) years from the date you received this copy of Musim, the developer will, on request, provide the complete corresponding GPLv3 source code for the exact FFmpeg version above. Contact: **tanya@wartaai.com**.

A full copy of the GNU General Public License v3 is available at https://www.gnu.org/licenses/gpl-3.0.html.

---

Musim is a sub-project by **WartaAI** (https://wartaai.com), created by Fahim Zahar, collaboratively with Claude (Fable 5 & Opus 4.8). The Musim application source is separate from, and does not modify, the open-source projects listed above.
