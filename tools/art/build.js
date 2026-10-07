// Renders Riftbound's UI art ("Shattered Obsidian" style) to PNGs in art/ui/.
// Each asset is an SVG/HTML snippet rendered by headless Edge/Chrome with a
// transparent background. Usage: node tools/art/build.js [assetName ...]
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const OUT = path.join(__dirname, '..', '..', 'art', 'ui');
const BROWSERS = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
];
const BROWSER = BROWSERS.find(b => fs.existsSync(b));

const C = {
  ink: '#07050a', slab: '#140d17', slab2: '#22162a', bronze: '#a8773f', gold: '#e9c27a',
  rift: '#b26cff', riftHot: '#e7c8ff',
  Fire: '#ff6a2b', Water: '#3c9cff', Earth: '#c08446', Air: '#9ff0d8', Lightning: '#fae13c',
};

// Shared SVG defs: textures, ink roughness, metal.
const DEFS = `
<defs>
  <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="ink" x="-10%" y="-10%" width="120%" height="120%"><feTurbulence baseFrequency=".9" numOctaves="2" seed="4"/><feDisplacementMap in="SourceGraphic" scale="2.4"/></filter>
  <filter id="chip" x="-5%" y="-5%" width="110%" height="110%"><feTurbulence type="fractalNoise" baseFrequency=".05" numOctaves="3" seed="11" result="t"/><feDisplacementMap in="SourceGraphic" in2="t" scale="6" xChannelSelector="R" yChannelSelector="G"/></filter>
  <filter id="grit"><feTurbulence type="fractalNoise" baseFrequency="1.1" numOctaves="2" result="g"/><feColorMatrix in="g" type="saturate" values="0" result="gg"/><feComposite in="gg" in2="SourceGraphic" operator="in" result="m"/><feBlend in="SourceGraphic" in2="m" mode="multiply"/></filter>
  <filter id="stone" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency=".38" numOctaves="2" seed="2" result="fine"/>
    <feColorMatrix in="fine" type="matrix" values="0.16 0 0 0 0.42  0.16 0 0 0 0.42  0.16 0 0 0 0.42  0 0 0 0 1" result="fineG"/>
    <feTurbulence type="fractalNoise" baseFrequency=".02" numOctaves="4" seed="7" result="big"/>
    <feColorMatrix in="big" type="matrix" values="0.9 0 0 0 0.35  0.9 0 0 0 0.35  0.9 0 0 0 0.35  0 0 0 0 1" result="bigG"/>
    <feBlend in="SourceGraphic" in2="bigG" mode="multiply" result="a"/>
    <feBlend in="fineG" in2="a" mode="overlay" result="b"/>
    <feComposite in="b" in2="SourceGraphic" operator="in"/>
  </filter>
  <pattern id="hatch" width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(35)"><line x1="0" y1="0" x2="0" y2="7" stroke="${C.ink}" stroke-width="1.8" stroke-opacity=".55"/></pattern>
  <linearGradient id="bronze" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e8b878"/><stop offset=".45" stop-color="#9a6a33"/><stop offset=".55" stop-color="#c8904d"/><stop offset="1" stop-color="#5c3a17"/></linearGradient>
  <linearGradient id="shade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".22"/><stop offset=".5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></linearGradient>
  <linearGradient id="slabFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.slab2}"/><stop offset="1" stop-color="${C.ink}"/></linearGradient>
  <clipPath id="lowerHalf"><polygon points="256,70 256,256 0,256 0,196"/></clipPath>
</defs>`;

// ---------------------------------------------------------------------------
// Skill glyphs (drawn in a 256x256 box, centred around 128,128)
// ---------------------------------------------------------------------------
const G = {
  RiftBolt: `<path d="M128 52 L168 128 L128 204 L88 128Z" fill="#d8b4ff"/><path d="M128 84 L148 128 L128 172 L108 128Z" fill="#fff" stroke-width="5"/>
    <path d="M60 170 l30 -20 M54 140 l26 -8 M70 196 l26 -26" fill="none" stroke="#e7c8ff" stroke-width="7"/>`,
  Fireball: `<path d="M150 70 q50 40 30 92 q-14 36 -54 36 q-44 0 -56 -40 q-10 -36 22 -60 q-2 22 14 30 q-10 -40 44 -58z" fill="#ff8a3a"/>
    <path d="M132 120 q26 20 14 48 q-10 16 -28 12 q-20 -6 -16 -28 q4 -18 30 -32z" fill="#ffe08a" stroke-width="6"/>`,
  TidalWave: `<path d="M40 180 q20 -90 100 -100 q60 -6 76 40 q-34 -26 -62 -4 q-24 20 -4 44 q-26 2 -40 -14 q-6 30 -30 34z" fill="#5fb0ff"/>
    <path d="M40 188 q46 -18 90 0 q44 18 90 0 v26 q-46 18 -90 0 q-44 -18 -90 0z" fill="#2a74d0"/>
    <path d="M150 100 q26 -6 44 12" fill="none" stroke="#e8f5ff" stroke-width="7"/>`,
  StoneSpike: `<path d="M56 200 L84 110 L108 200Z" fill="#c08446"/><path d="M100 200 L132 56 L164 200Z" fill="#d49a5c"/><path d="M156 200 L180 124 L204 200Z" fill="#a8703a"/>
    <path d="M40 200 h176" stroke-width="10"/><path d="M128 90 l10 40 l-14 30" fill="none" stroke="#5a3514" stroke-width="5"/>`,
  Gust: `<path d="M50 104 h96 q28 0 28 -24 q0 -22 -22 -22 q-18 0 -22 16" fill="none" stroke="#bff7e6" stroke-width="16"/>
    <path d="M50 104 h96 q28 0 28 -24 q0 -22 -22 -22 q-18 0 -22 16" fill="none" stroke="#07050a" stroke-width="5" stroke-opacity="0"/>
    <path d="M40 146 h140 q30 0 30 28 q0 26 -26 26 q-20 0 -24 -18" fill="none" stroke="#9ff0d8" stroke-width="16"/>
    <path d="M70 124 h70" stroke="#e8fff8" stroke-width="10"/>`,
  SparkBolt: `<path d="M146 40 L80 140 L124 140 L102 216 L180 104 L134 104 L160 40Z" fill="#ffe94a"/><path d="M146 52 L104 128" stroke="#fffbe0" stroke-width="6"/>`,
  SteamCloud: `<path d="M60 170 q-24 0 -24 -24 q0 -26 30 -26 q6 -34 44 -34 q30 0 42 26 q36 -6 44 26 q24 4 24 28 q0 22 -28 22z" fill="#e6eef5"/>
    <path d="M96 168 q8 -24 0 -40 q22 14 18 40z M150 168 q6 -20 -2 -34 q20 12 16 34z" fill="#ff8a3a" stroke-width="5"/>
    <path d="M60 196 q20 -12 40 0 q20 12 40 0 q20 -12 40 0" fill="none" stroke="#3c9cff" stroke-width="9"/>`,
  MagmaBurst: `<path d="M34 206 L80 116 L104 146 L128 84 L156 140 L172 120 L222 206Z" fill="#6e4220"/>
    <path d="M92 206 q12 -40 36 -50 q26 10 36 50z" fill="#ff6a2b"/><path d="M116 206 q4 -22 12 -28 q10 8 12 28z" fill="#ffe08a" stroke-width="5"/>
    <circle cx="164" cy="68" r="11" fill="#ffb347"/><circle cx="96" cy="74" r="8" fill="#ffb347"/><circle cx="132" cy="48" r="6" fill="#ffe08a"/>`,
  Firestorm: `<circle cx="128" cy="132" r="70" fill="none" stroke="#ff6a2b" stroke-width="22"/>
    <path d="M128 132 m-70 0 q20 -26 0 -46 q30 10 34 34 M128 132 m70 0 q-20 26 0 46 q-30 -10 -34 -34 M128 132 m0 -70 q26 20 46 0 q-10 30 -34 34 M128 132 m0 70 q-26 -20 -46 0 q10 -30 34 -34" fill="#ffb347" stroke-width="5"/>
    <circle cx="128" cy="132" r="20" fill="#bff7e6"/>`,
  PlasmaLance: `<path d="M40 216 L196 60" stroke="#ff6a2b" stroke-width="26"/><path d="M40 216 L196 60" stroke="#ffe94a" stroke-width="9"/>
    <path d="M196 60 L224 32 L210 74 Z" fill="#ffe94a"/><path d="M78 150 l18 -6 l-6 18 l18 -6" fill="none" stroke="#fffbe0" stroke-width="5"/>`,
  MudTrap: `<ellipse cx="128" cy="166" rx="92" ry="36" fill="#6b4524"/><ellipse cx="128" cy="160" rx="70" ry="22" fill="#8a5a2e" stroke-width="5"/>
    <path d="M70 160 q14 -12 28 0 q14 12 28 0 q14 -12 28 0 q14 12 28 0" fill="none" stroke="#3c9cff" stroke-width="8"/>
    <path d="M110 96 q18 -34 36 0 q-18 22 -36 0z" fill="#9fd2ff"/>`,
  FrostGale: `<g fill="none" stroke-linecap="round"><path d="M128 46 V210 M57 87 L199 169 M57 169 L199 87" stroke="#07050a" stroke-width="26"/>
    <path d="M128 46 V210 M57 87 L199 169 M57 169 L199 87" stroke="#e8f8ff" stroke-width="13"/>
    <path d="M106 62 l22 20 l22 -20 M106 194 l22 -20 l22 20" stroke="#07050a" stroke-width="16"/><path d="M106 62 l22 20 l22 -20 M106 194 l22 -20 l22 20" stroke="#7cc4ff" stroke-width="7"/></g>
    <circle cx="128" cy="128" r="16" fill="#3c9cff"/>`,
  ChainShock: `<rect x="44" y="96" width="76" height="44" rx="22" fill="none" stroke="#9fd2ff" stroke-width="16"/>
    <rect x="136" y="116" width="76" height="44" rx="22" fill="none" stroke="#3c9cff" stroke-width="16"/>
    <path d="M118 60 L96 104 L128 104 L108 150 L158 92 L126 92 L144 60Z" fill="#ffe94a"/>`,
  Sandstorm: `<path d="M64 80 h120 M48 112 h150 M70 144 h110 M94 176 h70 M116 206 h30" stroke="#d9a768" stroke-width="16"/>
    <path d="M190 80 q26 16 0 32 M200 112 q20 16 -18 32" fill="none" stroke="#9ff0d8" stroke-width="8"/>
    <g fill="#ffd79a" stroke-width="3"><circle cx="58" cy="140" r="6"/><circle cx="196" cy="168" r="5"/><circle cx="80" cy="192" r="5"/></g>`,
  MagnetQuake: `<path d="M74 60 v70 q0 54 54 54 q54 0 54 -54 v-70 h-36 v70 q0 18 -18 18 q-18 0 -18 -18 v-70z" fill="#c08446"/>
    <path d="M74 60 h36 v26 h-36z M146 60 h36 v26 h-36z" fill="#ffe94a"/>
    <path d="M40 222 l30 -14 l20 12 l26 -16 l24 16 l28 -14 l22 12 l26 -10" fill="none" stroke-width="8"/>`,
  Thunderstorm: `<path d="M66 128 q-26 0 -26 -26 q0 -28 32 -28 q8 -34 48 -34 q34 0 46 28 q38 -4 46 30 q22 6 22 30 q0 24 -30 24z" fill="#8f9bb8"/>
    <path d="M130 140 L108 188 L134 188 L118 228 L162 172 L136 172 L152 140Z" fill="#ffe94a"/>
    <path d="M76 160 l-10 22 M198 160 l-8 18" stroke="#9ff0d8" stroke-width="8"/>`,
  Dash: `<path d="M70 72 L130 128 L70 184" fill="none" stroke="#d8b4ff" stroke-width="22"/><path d="M130 72 L190 128 L130 184" fill="none" stroke="#e7c8ff" stroke-width="22"/>
    <path d="M30 100 h26 M24 128 h30 M30 156 h26" stroke="#b26cff" stroke-width="8"/>`,
};

// Shard colours per skill: [top, bottom]
const SHARD = {
  RiftBolt: ['#c69bff', '#3b1470'], Dash: ['#6b4a8f', '#160a24'],
  Fireball: [C.Fire, '#6a1c06'], TidalWave: [C.Water, '#0f2f66'], StoneSpike: [C.Earth, '#4a2a10'], Gust: [C.Air, '#1f5a4c'], SparkBolt: [C.Lightning, '#6a5208'],
  SteamCloud: [C.Fire, C.Water], MagmaBurst: [C.Fire, C.Earth], Firestorm: [C.Fire, C.Air], PlasmaLance: [C.Fire, C.Lightning],
  MudTrap: [C.Water, C.Earth], FrostGale: [C.Water, C.Air], ChainShock: [C.Water, C.Lightning],
  Sandstorm: [C.Earth, C.Air], MagnetQuake: [C.Earth, C.Lightning], Thunderstorm: [C.Air, C.Lightning],
};

const HEX = '128,8 226,62 218,186 128,248 36,184 30,60';
const HEX_IN = '128,20 214,68 207,180 128,234 46,178 41,66';
const HEX_IN2 = '128,40 196,78 190,170 128,214 64,168 60,78';

function shard(top, bottom, glyph, opts = {}) {
  const darkTop = opts.dim ? 0.55 : 0;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">${DEFS}
  <polygon points="${HEX}" fill="${C.ink}" stroke="${C.ink}" stroke-width="10" filter="url(#chip)"/>
  <g filter="url(#chip)">
    <polygon points="${HEX_IN}" fill="${top}"/>
    <polygon points="${HEX_IN}" fill="${bottom}" clip-path="url(#lowerHalf)"/>
    <polygon points="${HEX_IN}" fill="url(#hatch)" clip-path="url(#lowerHalf)" opacity=".6"/>
    <polygon points="${HEX_IN}" fill="url(#shade)"/>
    <polygon points="${HEX_IN}" fill="#000" opacity="${darkTop}"/>
    <polygon points="${HEX_IN}" fill="none" stroke="${C.gold}" stroke-width="5" filter="url(#grit)"/>
    <polygon points="${HEX_IN2}" fill="none" stroke="${C.bronze}" stroke-width="2.4" opacity=".85"/>
  </g>
  ${glyph ? `<g stroke="${C.ink}" stroke-width="9" stroke-linejoin="round" stroke-linecap="round" filter="url(#ink)" transform="translate(128 132) scale(.8) translate(-128 -128)">${glyph}</g>` : ''}
  <polyline points="41,66 70,96 62,124 90,150" fill="none" stroke="${C.riftHot}" stroke-width="3" filter="url(#glow)"/>
  <g filter="url(#grit)">
    <path d="M104 0 h48 v18 h-48z M104 238 h48 v18 h-48z" fill="url(#bronze)" stroke="${C.ink}" stroke-width="3"/>
  </g>
  <g fill="#2a1a08"><circle cx="114" cy="9" r="3.2"/><circle cx="142" cy="9" r="3.2"/><circle cx="114" cy="247" r="3.2"/><circle cx="142" cy="247" r="3.2"/></g>
</svg>`;
}

// 9-slice obsidian slab: chipped edge, bronze corner clamps, gold inlay.
// Keep all detail inside the 72px corners/edges; the centre is plain so it stretches cleanly.
function slab(w, h, opts = {}) {
  const fill = opts.fill || 'url(#slabFill)';
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${DEFS}
  <g filter="url(#chip)">
    <path d="M18 10 H${w - 18} L${w - 8} 22 V${h - 22} L${w - 18} ${h - 10} H18 L8 ${h - 22} V22Z" fill="${C.ink}"/>
    <path d="M22 16 H${w - 22} L${w - 14} 26 V${h - 26} L${w - 22} ${h - 16} H22 L14 ${h - 26} V26Z" fill="${fill}" filter="url(#stone)"/>
    <path d="M22 16 H${w - 22} L${w - 14} 26 V${h - 26} L${w - 22} ${h - 16} H22 L14 ${h - 26} V26Z" fill="none" stroke="${C.bronze}" stroke-width="3"/>
    <path d="M30 26 H${w - 30} L${w - 24} 32 V${h - 32} L${w - 30} ${h - 26} H30 L24 ${h - 32} V32Z" fill="none" stroke="${C.gold}" stroke-width="1.2" opacity=".45"/>
  </g>
  <polyline points="${w - 14},44 ${w - 34},54 ${w - 28},66" fill="none" stroke="${C.ink}" stroke-width="2"/>
  <polyline points="14,${h - 44} 34,${h - 50} 40,${h - 36}" fill="none" stroke="${C.riftHot}" stroke-width="2.2" filter="url(#glow)"/>
  <g filter="url(#grit)" fill="url(#bronze)" stroke="${C.ink}" stroke-width="2.5">
    <path d="M4 34 V4 H34 V14 H14 V34Z"/><path d="M${w - 4} 34 V4 H${w - 34} V14 H${w - 14} V34Z"/>
    <path d="M4 ${h - 34} V${h - 4} H34 V${h - 14} H14 V${h - 34}Z"/><path d="M${w - 4} ${h - 34} V${h - 4} H${w - 34} V${h - 14} H${w - 14} V${h - 34}Z"/>
  </g>
  <g fill="#2a1a08"><circle cx="9" cy="9" r="2.6"/><circle cx="${w - 9}" cy="9" r="2.6"/><circle cx="9" cy="${h - 9}" r="2.6"/><circle cx="${w - 9}" cy="${h - 9}" r="2.6"/></g>
</svg>`;
}

// Banner: wide chamfered slab with a rift crack along the bottom edge and a top clamp.
function banner(w, h) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${DEFS}
  <g filter="url(#chip)">
    <path d="M40 8 H${w - 40} L${w - 6} 40 L${w - 22} ${h - 12} H22 L6 40Z" fill="${C.ink}"/>
    <path d="M44 14 H${w - 44} L${w - 14} 42 L${w - 28} ${h - 18} H28 L14 42Z" fill="url(#slabFill)" filter="url(#stone)"/>
    <path d="M44 14 H${w - 44}" stroke="${C.bronze}" stroke-width="4"/>
  </g>
  <polyline points="70,${h - 16} 160,${h - 22} 200,${h - 14} 330,${h - 20} 380,${h - 13} 520,${h - 21} 620,${h - 14} ${w - 70},${h - 19}" fill="none" stroke="${C.rift}" stroke-width="3" filter="url(#glow)"/>
  <g filter="url(#grit)" fill="url(#bronze)" stroke="${C.ink}" stroke-width="2.5">
    <path d="M10 44 l36 -36 h26 l-36 36z"/><path d="M${w - 10} 44 l-36 -36 h-26 l36 36z"/>
    <path d="M${w / 2 - 70} 2 h140 l-10 13 h-120z"/>
  </g>
  <g fill="#2a1a08"><circle cx="${w / 2 - 48}" cy="8" r="3"/><circle cx="${w / 2}" cy="8" r="3"/><circle cx="${w / 2 + 48}" cy="8" r="3"/></g>
</svg>`;
}

// Health/XP bar frame (9-slice): dark trough, bronze rim, pointed right end.
function barFrame(w, h) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${DEFS}
  <g filter="url(#chip)">
    <path d="M6 6 H${w - 26} L${w - 6} ${h / 2} L${w - 26} ${h - 6} H6Z" fill="${C.ink}"/>
    <path d="M6 6 H${w - 26} L${w - 6} ${h / 2} L${w - 26} ${h - 6} H6Z" fill="none" stroke="url(#bronze)" stroke-width="5"/>
  </g>
  <g filter="url(#grit)" fill="url(#bronze)" stroke="${C.ink}" stroke-width="2"><path d="M0 0 h18 v${h} h-18z"/></g>
  <g fill="#2a1a08"><circle cx="9" cy="10" r="2.4"/><circle cx="9" cy="${h - 10}" r="2.4"/></g>
</svg>`;
}

function coin() {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">${DEFS}
  <g filter="url(#chip)"><circle cx="64" cy="64" r="58" fill="${C.ink}"/>
  <circle cx="64" cy="64" r="50" fill="url(#bronze)" filter="url(#grit)"/>
  <circle cx="64" cy="64" r="50" fill="#f0c060" opacity=".55"/>
  <circle cx="64" cy="64" r="40" fill="none" stroke="#6e4512" stroke-width="3"/></g>
  <polygon points="64,30 86,64 64,98 42,64" fill="#3b1470" stroke="${C.ink}" stroke-width="5"/>
  <polygon points="64,42 76,64 64,86 52,64" fill="${C.rift}"/>
  <polyline points="64,42 70,58 62,70" fill="none" stroke="${C.riftHot}" stroke-width="3" filter="url(#glow)"/>
</svg>`;
}

// Tileable grain to lay over panels and bars (ScaleType.Tile).
function grain() {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><filter id="n"><feTurbulence type="fractalNoise" baseFrequency=".8" numOctaves="3" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.2 1.35"/></filter><rect width="256" height="256" filter="url(#n)"/></svg>`;
}

// Large soft smoke blotches to stretch over a panel.
function smoke() {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><filter id="s"><feTurbulence type="fractalNoise" baseFrequency=".009" numOctaves="5" seed="5" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.6 1.5"/></filter><rect width="512" height="512" filter="url(#s)"/></svg>`;
}

function vignette() {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><defs><radialGradient id="v" cx=".5" cy=".5" r=".72"><stop offset=".5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".88"/></radialGradient></defs><rect width="512" height="512" fill="url(#v)"/></svg>`;
}

const ASSETS = {};
for (const id of Object.keys(G)) {
  const [top, bottom] = SHARD[id];
  ASSETS['icon_' + id] = { w: 256, h: 256, svg: shard(top, bottom, G[id]) };
}
ASSETS.icon_Empty = { w: 256, h: 256, svg: shard('#3a2a3e', '#140d17', null, { dim: true }) };
ASSETS.medallion = { w: 256, h: 256, svg: shard('#3b1470', '#120624', null) };
ASSETS.slab = { w: 256, h: 256, svg: slab(256, 256) };
ASSETS.row = { w: 512, h: 128, svg: slab(512, 128, { fill: 'url(#slabFill)' }) };
ASSETS.banner = { w: 800, h: 128, svg: banner(800, 128) };
ASSETS.bar = { w: 256, h: 48, svg: barFrame(256, 48) };
ASSETS.coin = { w: 128, h: 128, svg: coin() };
ASSETS.grain = { w: 256, h: 256, svg: grain() };
ASSETS.smoke = { w: 512, h: 512, svg: smoke() };
ASSETS.vignette = { w: 512, h: 512, svg: vignette() };

function render(name) {
  const a = ASSETS[name];
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}svg{display:block}</style></head><body>${a.svg}</body></html>`;
  const htmlPath = path.join(OUT, '_src', name + '.html');
  fs.writeFileSync(htmlPath, html);
  const png = path.join(OUT, name + '.png');
  execFileSync(BROWSER, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
    '--default-background-color=00000000', `--window-size=${a.w},${a.h}`, '--virtual-time-budget=3000',
    `--screenshot=${png}`, 'file:///' + htmlPath.replace(/\\/g, '/'),
  ], { stdio: 'ignore' });
  return png;
}

fs.mkdirSync(path.join(OUT, '_src'), { recursive: true });
const names = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(ASSETS);
for (const n of names) {
  if (!ASSETS[n]) { console.error('unknown asset ' + n); continue; }
  render(n);
  console.log('rendered ' + n);
}
