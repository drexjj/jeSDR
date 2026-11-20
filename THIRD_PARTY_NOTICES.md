# jeSDR — copyright and third-party notices

jeSDR is Copyright © 2026 J. Kujawa, W9JES.

jeSDR is built on the sBitx software created by Ashhar Farhan, VU2ESE
(HF Signals). The enhanced code is by J. Kujawa, W9JES, with code
contributed by:

- Jon, W2JON
- Alan, N1QM
- Lee, W4WHL
- Matt, NM7D
- Lars, OZ7BX
- Jeff, KF7DYU
- Mike, KB2ML
- Shawn, K7IHZ
- Jared, KJ5DTK
- Fabrizio, F4VUK
- Bob, KD8CGH
- Bob, W7PUA
- Phil, KA9Q
- Gerald, K5SDR
- Steve, N3SB

jeSDR includes and uses software written by others. Each component stays
under its own license, listed here with its copyright holders. Where a
license requires its text to travel with the software, the text is below
or referenced. Ship this file with every copy of jeSDR (source or binary).

## Built into jeSDR

| Component | Copyright | License | Where |
|---|---|---|---|
| CivetWeb 1.16 | © 2013–2021 The CivetWeb developers; © 2004–2013 Sergey Lyubka; © 2013 No Face Press, LLC (Thomas Davis); © 2013 F-Secure Corporation | MIT | `src/civetweb/` (`LICENSE.md` there) |
| MD5 (inside CivetWeb, `md5.inl`) | © 1999, 2000, 2002 Aladdin Enterprises; L. Peter Deutsch | zlib-style (text below) | `src/civetweb/md5.inl` |
| SHA-1 (inside CivetWeb, `sha1.inl`) | Steve Reid, James H. Brown and others | public domain | `src/civetweb/sha1.inl` |
| inih | © 2009–2020 Ben Hoyt | BSD-3-Clause | `src/ini.c`, `src/ini.h` |
| ft8_lib | © 2018 Kārlis Goba | MIT | `src/ft8_lib/` (`common/monitor.*` modified for FT2) |
| KISS FFT | © 2003–2010 Mark Borgerding | BSD-3-Clause | `src/ft8_lib/fft/`; also built in double precision by `src/kiss_fft_double.c`. All of jeSDR's FFTs use it (`src/fft_compat.*`) |
| sBitx | Ashhar Farhan, VU2ESE (HF Signals), who created the original code; enhanced by J. Kujawa, W9JES, and the contributors named above | GPL-3.0 as stated in the sBitx sources (the sBitx repository has no license file) | origin of `src/jesdr_core.c` (was `sbitx.c`), `src/jesdr_sound.c` (was `sbitx_sound.c`), `src/fft_filter.c`, `src/si5351v2.c`, `src/queue.c`, `src/remote.c`, `src/vfo.c`, `src/sdr.h`, `src/sound.h`, and parts of `src/modem_cw.c`, `src/hamlib.c`, `src/logbook.c` |
| I²C bit-banging bus | Marek Wyborski (via sBitx) | not stated | `src/i2cbb.c`, `src/i2cbb.h` |
| Natural Earth 1:110m land | Natural Earth (naturalearthdata.com) | public domain | the coastline of the FT8 grid map, `web/world.js` |
| world-atlas | © 2013–2019 Michael Bostock | ISC | the TopoJSON packaging of the Natural Earth data that `web/world.js` was converted from |

## FreeDV RADE, built into every release (sources fetched at build time by `tools/fetch_rade.sh`)

| Component | Copyright | License |
|---|---|---|
| RADE (`rade_c`) | David Rowe, VK5DGR, and the FreeDV project | BSD-2-Clause |
| Opus | Xiph.Org Foundation and the Opus contributors | BSD-3-Clause |

When RADE is built in, ship `third_party/rade_c/LICENSE` and
`third_party/opus/COPYING` with the program.

## Libraries linked on the Pi (not shipped in this tree)

| Library | Copyright | License |
|---|---|---|
| OpenSSL (`libssl`, `libcrypto`) | The OpenSSL Project Authors | Apache-2.0 for OpenSSL 3 (Raspberry Pi OS Bookworm and later); the OpenSSL/SSLeay license for 1.1.1 (Bullseye) (dynamically linked) |
| ALSA library (`libasound`) | The ALSA project | LGPL-2.1-or-later (dynamically linked) |
| GNU C library | Free Software Foundation and contributors | LGPL-2.1-or-later (dynamically linked) |

## Data and protocols

Not code, credited with thanks:

- Big CTY country file — Jim Reisert, AD1C, www.country-files.com (downloaded
  by `tools/fetch_cty.sh`, not shipped).
- Solar and band-condition data — N0NBH, www.hamqsl.com (fetched hourly by the
  radio for the band-conditions indicator, not shipped).
- FT8 and FT4 — Joe Taylor, K1JT, and Steve Franke, K9AN (WSJT-X).
- FT2 — Uwe Risse, DG2YCB (WSJT-X Improved / WS).
- PSK31 and Varicode — Peter Martinez, G3PLX; ITU-R M.2034.
- RTTY automatic threshold correction — Kok Chen, W7AY.
- CESSB — David Hershberger, W9GR, "Controlled Envelope Single Sideband",
  QEX Nov/Dec 2014.
- Iambic keyer timing — KC4IFB, QEX Sept/Oct 2009.
- FreeDV calling frequencies — the FreeDV project.
- TCI (Expert Electronics), HPSDR Protocol 1 (OpenHPSDR) and the Hamlib
  rigctld protocol (the Hamlib project).

---

## License texts

### MIT — CivetWeb

```
Copyright (c) 2013-2021 The CivetWeb developers (CREDITS.md)
Copyright (c) 2004-2013 Sergey Lyubka
Copyright (c) 2013 No Face Press, LLC (Thomas Davis)
Copyright (c) 2013 F-Secure Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

### zlib-style — MD5 in CivetWeb

```
Copyright (C) 1999, 2000, 2002 Aladdin Enterprises.  All rights reserved.

This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

L. Peter Deutsch
ghost@aladdin.com
```

### MIT — ft8_lib

```
MIT License

Copyright (c) 2018 Kārlis Goba

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

### BSD-3-Clause — inih, KISS FFT (and Opus, when built in)

```
Copyright (c) 2009-2020, Ben Hoyt                 (inih)
Copyright (c) 2003-2010, Mark Borgerding          (KISS FFT)
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from this
   software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
```

### BSD-2-Clause — RADE (when built in)

See `third_party/rade_c/LICENSE` for its copyright line. The terms are the
BSD-3-Clause text above without clause 3.

### Apache-2.0 — OpenSSL 3

Used as a shared library from the operating system. The license text is at
https://www.apache.org/licenses/LICENSE-2.0 and in
`/usr/share/doc/libssl3/copyright` on the Pi.

### GPL-3.0 — sBitx-derived code

The sBitx sources state GPL-3.0; the text is at
https://www.gnu.org/licenses/gpl-3.0.txt. While that code is part of jeSDR,
a copy must accompany any binary distribution together with the
corresponding source code, unless the sBitx copyright holders license it to
you on other terms.

### ISC — world-atlas

```
Copyright 2013-2019 Michael Bostock

Permission to use, copy, modify, and/or distribute this software for any purpose
with or without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
THIS SOFTWARE.
```

### LGPL — ALSA library, GNU C library

These are used as shared libraries from the operating system and can be
replaced by the user; their licenses are at
https://www.gnu.org/licenses/lgpl-2.1.txt.
