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
const BROWSER = process.env.BROWSER || BROWSERS.find(b => fs.existsSync(b));

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
  MagmaBurst: `<path d="M54 50 L146 132" stroke="#7a1e08" stroke-width="48"/><path d="M60 56 L146 132" stroke="#ff6a2b" stroke-width="30"/><path d="M70 64 L146 132" stroke="#ffe08a" stroke-width="14"/>
    <ellipse cx="150" cy="212" rx="78" ry="16" fill="#ff6a2b"/><ellipse cx="150" cy="210" rx="46" ry="8" fill="#ffe08a" stroke-width="4"/>
    <circle cx="158" cy="146" r="40" fill="#4a2a1a"/><path d="M138 128 l18 12 l-6 18 M170 132 l10 22" fill="none" stroke="#ff8a3a" stroke-width="6"/>`,
  Firestorm: `<circle cx="128" cy="132" r="70" fill="none" stroke="#ff6a2b" stroke-width="22"/>
    <path d="M128 132 m-70 0 q20 -26 0 -46 q30 10 34 34 M128 132 m70 0 q-20 26 0 46 q-30 -10 -34 -34 M128 132 m0 -70 q26 20 46 0 q-10 30 -34 34 M128 132 m0 70 q-26 -20 -46 0 q10 -30 34 -34" fill="#ffb347" stroke-width="5"/>
    <circle cx="128" cy="132" r="20" fill="#bff7e6"/>`,
  PlasmaLance: `<path d="M40 216 L196 60" stroke="#ff6a2b" stroke-width="26"/><path d="M40 216 L196 60" stroke="#ffe94a" stroke-width="9"/>
    <path d="M196 60 L224 32 L210 74 Z" fill="#ffe94a"/><path d="M78 150 l18 -6 l-6 18 l18 -6" fill="none" stroke="#fffbe0" stroke-width="5"/>`,
  MudTrap: `<path d="M36 206 q44 -18 88 0 q44 18 100 -4" fill="none" stroke="#8a5a2e" stroke-width="16"/>
    <circle cx="146" cy="124" r="64" fill="#6b4524"/><circle cx="124" cy="104" r="10" fill="#a0805e" stroke-width="5"/><circle cx="168" cy="142" r="12" fill="#a0805e" stroke-width="5"/><circle cx="158" cy="90" r="6" fill="#a0805e" stroke-width="4"/>
    <path d="M30 98 h34 M22 126 h40 M30 154 h34" stroke="#e8f8ff" stroke-width="9"/>`,
  FrostGale: `<g fill="none" stroke-linecap="round"><path d="M128 46 V210 M57 87 L199 169 M57 169 L199 87" stroke="#07050a" stroke-width="26"/>
    <path d="M128 46 V210 M57 87 L199 169 M57 169 L199 87" stroke="#e8f8ff" stroke-width="13"/>
    <path d="M106 62 l22 20 l22 -20 M106 194 l22 -20 l22 20" stroke="#07050a" stroke-width="16"/><path d="M106 62 l22 20 l22 -20 M106 194 l22 -20 l22 20" stroke="#7cc4ff" stroke-width="7"/></g>
    <circle cx="128" cy="128" r="16" fill="#3c9cff"/>`,
  ChainShock: `<rect x="44" y="96" width="76" height="44" rx="22" fill="none" stroke="#9fd2ff" stroke-width="16"/>
    <rect x="136" y="116" width="76" height="44" rx="22" fill="none" stroke="#3c9cff" stroke-width="16"/>
    <path d="M118 60 L96 104 L128 104 L108 150 L158 92 L126 92 L144 60Z" fill="#ffe94a"/>`,
  Sandstorm: `<path d="M36 214 L60 150 L84 214 Z M82 214 L108 128 L134 214 Z M122 214 L148 128 L174 214 Z M172 214 L196 150 L220 214Z" fill="#c08446"/>
    <path d="M128 30 V100" stroke="#9ff0d8" stroke-width="18"/><path d="M96 78 L128 114 L160 78" fill="none" stroke="#9ff0d8" stroke-width="18"/>`,
  MagnetQuake: `<path d="M74 60 v70 q0 54 54 54 q54 0 54 -54 v-70 h-36 v70 q0 18 -18 18 q-18 0 -18 -18 v-70z" fill="#c08446"/>
    <path d="M74 60 h36 v26 h-36z M146 60 h36 v26 h-36z" fill="#ffe94a"/>
    <path d="M40 222 l30 -14 l20 12 l26 -16 l24 16 l28 -14 l22 12 l26 -10" fill="none" stroke-width="8"/>`,
  Thunderstorm: `<path d="M66 128 q-26 0 -26 -26 q0 -28 32 -28 q8 -34 48 -34 q34 0 46 28 q38 -4 46 30 q22 6 22 30 q0 24 -30 24z" fill="#8f9bb8"/>
    <path d="M130 140 L108 188 L134 188 L118 228 L162 172 L136 172 L152 140Z" fill="#ffe94a"/>
    <path d="M76 160 l-10 22 M198 160 l-8 18" stroke="#9ff0d8" stroke-width="8"/>`,
  Flask: `<path d="M108 44 h40 v14 h-40z" fill="#8a5a2e"/><path d="M112 58 h32 v26 q46 20 46 70 q0 56 -62 56 q-62 0 -62 -56 q0 -50 46 -70z" fill="#3a1820"/>
    <path d="M78 148 q50 -22 100 0 q4 50 -50 56 q-54 -6 -50 -56z" fill="#ff4a5e"/>
    <path d="M86 150 q42 -14 84 0" fill="none" stroke="#ffb3bd" stroke-width="5"/>
    <path d="M100 108 q-12 16 -12 34" fill="none" stroke="#f1e3c6" stroke-width="6" stroke-opacity=".8"/>
    <circle cx="150" cy="176" r="7" fill="#ffd0d6" stroke-width="3"/><circle cx="118" cy="186" r="4" fill="#ffd0d6" stroke-width="2"/>`,
  Block: `<path d="M128 36 L204 64 V126 q0 64 -76 98 q-76 -34 -76 -98 V64 Z" fill="#b26cff"/>
    <path d="M128 60 L182 80 V126 q0 46 -54 72 q-54 -26 -54 -72 V80 Z" fill="#e7c8ff" stroke-width="5"/>
    <path d="M128 90 L150 128 L128 166 L106 128 Z" fill="#7a3fd0" stroke-width="5"/>`,
  Dash: `<path d="M70 72 L130 128 L70 184" fill="none" stroke="#d8b4ff" stroke-width="22"/><path d="M130 72 L190 128 L130 184" fill="none" stroke="#e7c8ff" stroke-width="22"/>
    <path d="M30 100 h26 M24 128 h30 M30 156 h26" stroke="#b26cff" stroke-width="8"/>`,
};

// Shard colours per skill: [top, bottom]
const SHARD = {
  RiftBolt: ['#c69bff', '#3b1470'], Block: ['#8a5ad0', '#1d0c36'], Dash: ['#6b4a8f', '#160a24'], Flask: ['#c2203a', '#3a0812'],
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


// Round relic frame for collectible items, tinted by rarity.
function relic(rim, glyph) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">${DEFS}
  <defs><radialGradient id="rg" cx=".5" cy=".42" r=".6"><stop offset="0" stop-color="${rim}" stop-opacity=".35"/><stop offset=".75" stop-color="#140d17"/><stop offset="1" stop-color="#07050a"/></radialGradient></defs>
  <g filter="url(#chip)">
    <circle cx="128" cy="128" r="118" fill="${C.ink}"/>
    <circle cx="128" cy="128" r="106" fill="url(#rg)"/>
    <circle cx="128" cy="128" r="106" fill="none" stroke="url(#bronze)" stroke-width="9" filter="url(#grit)"/>
    <circle cx="128" cy="128" r="94" fill="none" stroke="${rim}" stroke-width="3" opacity=".9"/>
  </g>
  <g stroke="${C.ink}" stroke-width="9" stroke-linejoin="round" stroke-linecap="round" filter="url(#ink)" transform="translate(128 130) scale(.88) translate(-128 -128)">${glyph}</g>
  <g fill="url(#bronze)" stroke="${C.ink}" stroke-width="2.5" filter="url(#grit)"><path d="M118 2 h20 l6 14 h-32z"/><path d="M118 254 h20 l6 -14 h-32z"/></g>
</svg>`;
}
const ITEM_GLYPH = {
  RiftShard: `<path d="M128 40 L160 110 L128 210 L96 110Z" fill="#c69bff"/><path d="M78 118 L100 100 L112 170 L84 196Z" fill="#8a52e0"/><path d="M178 118 L156 100 L144 170 L172 196Z" fill="#a874ff"/><path d="M128 64 L144 110 L128 170" fill="none" stroke="#f2e4ff" stroke-width="6"/>`,
  HuskIchor: `<path d="M108 52 h40 v18 h-40z" fill="#5c3a17"/><path d="M112 70 h32 v20 q30 18 30 56 q0 52 -46 52 q-46 0 -46 -52 q0 -38 30 -56z" fill="#2a1630"/><path d="M90 150 q38 -16 76 0 q2 42 -38 46 q-40 -4 -38 -46z" fill="#7ad36b"/><circle cx="142" cy="168" r="7" fill="#d6ffcf" stroke-width="3"/>`,
  EmberCore: `<circle cx="128" cy="128" r="66" fill="#ff7a2b"/><path d="M98 96 l22 26 l-8 24 l26 22 M150 86 l-10 34 l24 12" fill="none" stroke="#ffe08a" stroke-width="7"/><circle cx="128" cy="128" r="66" fill="none" stroke-width="9"/>`,
};
const BAG_GLYPH = `<path d="M70 104 q0 -10 10 -10 h96 q10 0 10 10 l10 92 q0 14 -14 14 h-108 q-14 0 -14 -14z" fill="#8a5a2e"/>
  <path d="M100 94 q0 -40 28 -40 q28 0 28 40" fill="none" stroke-width="10"/><path d="M100 94 q0 -40 28 -40 q28 0 28 40" fill="none" stroke="#c8904d" stroke-width="5"/>
  <path d="M66 120 h124 v26 h-124z" fill="#5c3a17"/><rect x="114" y="124" width="28" height="30" rx="4" fill="#e9c27a"/>`;


const STAT_GLYPH = {
  Vitality: `<path d="M128 206 C60 160 44 124 52 96 C60 66 100 58 128 90 C156 58 196 66 204 96 C212 124 196 160 128 206Z" fill="#e8364a"/><path d="M84 96 q8 -18 28 -12" fill="none" stroke="#ffc2c9" stroke-width="7"/>`,
  Might: `<path d="M64 196 q-34 -46 -6 -96 q4 28 22 34 q-6 -52 34 -86 q-2 36 20 48 q10 -34 40 -48 q-8 40 16 56 q14 -14 12 -34 q34 44 4 126z" fill="#ff7a2b" stroke="none"/>
    <path d="M78 196 q-18 -34 2 -66 q6 20 20 22 q0 -34 28 -58 q2 30 22 40 q10 -22 28 -30 q-6 30 10 44 q10 -8 10 -22 q18 36 -6 70z" fill="#ffb347" stroke="none"/>
    <g stroke="#07050a" stroke-width="9" stroke-linejoin="round">
      <rect x="92" y="88" width="30" height="50" rx="14" fill="#f2d2b0"/><rect x="120" y="82" width="30" height="56" rx="14" fill="#f2d2b0"/>
      <rect x="148" y="86" width="30" height="52" rx="14" fill="#f2d2b0"/><rect x="176" y="96" width="26" height="44" rx="12" fill="#f2d2b0"/>
      <path d="M92 124 h110 v40 q0 34 -34 34 h-48 q-28 0 -28 -30z" fill="#f2d2b0"/>
      <path d="M76 120 q22 -10 46 8 q10 10 2 24 l-22 -6 q-20 -4 -26 -26z" fill="#e8bc96"/>
      <path d="M110 198 h56 v30 h-56z" fill="#a8773f"/></g>
    <path d="M100 100 v20 M128 94 v22 M156 98 v20" stroke="#fff3e6" stroke-width="5" stroke-linecap="round"/>`,
  Swiftness: `<g stroke="#07050a" stroke-width="10" stroke-linejoin="round">
    <path d="M70 116 q-40 -20 -54 -58 q30 6 44 24 q-14 -34 -4 -56 q26 20 36 54 q4 -26 20 -40 q6 30 -6 60z" fill="#e8fff8"/>
    <path d="M104 58 h58 v84 q0 10 10 14 l40 14 q20 8 20 28 v8 h-150 v-24 q0 -14 8 -26 l14 -20z" fill="#2f8f78"/>
    <path d="M90 206 h148 v12 q0 10 -10 10 h-128 q-10 0 -10 -10z" fill="#6e4520"/>
    <path d="M104 58 h58 v20 h-58z" fill="#e9c27a"/></g>
    <path d="M114 104 h38 M114 126 h36" stroke="#9ff0d8" stroke-width="7" stroke-linecap="round"/>
    <path d="M24 170 h44 M14 196 h50" stroke="#9ff0d8" stroke-width="9" stroke-linecap="round"/>`,
  Focus: `<path d="M80 50 h96 v10 q0 40 -36 68 q36 28 36 68 v10 h-96 v-10 q0 -40 36 -68 q-36 -28 -36 -68z" fill="#3b1470"/><path d="M96 66 h64 q-4 30 -32 50 q-28 -20 -32 -50z" fill="#c69bff"/><path d="M104 196 q24 -34 48 0z" fill="#c69bff"/><path d="M70 50 h116 M70 206 h116" stroke="#e9c27a" stroke-width="10"/>`,
};

// ---------------------------------------------------------------------------
// Lobby menu icons ("Bold Vanguard"): bright painted icons with a thick ink
// outline, a white shine and a soft coloured glow, on a transparent
// background. The framed tile and its label are built in-engine (LobbyMenu).
// ---------------------------------------------------------------------------
const VG = '#0d0a14';
const vgrad = (id, top, mid, bot) => `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${top}"/><stop offset=".5" stop-color="${mid}"/><stop offset="1" stop-color="${bot}"/></linearGradient>`;
const VDEFS = `<defs>
  ${vgrad('vRed', '#ff9aa8', '#ff3d5e', '#a0102e')}${vgrad('vGold', '#fff1b0', '#f2b53c', '#a5600f')}
  ${vgrad('vBlue', '#bfe6ff', '#38a3ff', '#1146a8')}${vgrad('vOrange', '#ffd99a', '#ff9f1c', '#b4520a')}
  ${vgrad('vGreen', '#c4ffd9', '#2fd37a', '#0c7a43')}${vgrad('vViolet', '#f0d4ff', '#a855f7', '#4c1d95')}
  ${vgrad('vSteel', '#ffffff', '#c9d3e6', '#6f7b96')}${vgrad('vPaper', '#fffaf0', '#f6e6c4', '#d9bf8a')}
  ${vgrad('vWood', '#c98b52', '#8a5a2e', '#5a3516')}${vgrad('vNavy', '#9fc0ff', '#4f7dff', '#1c2f8a')}
  <filter id="vShadow" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="7" stdDeviation="0" flood-color="${VG}" flood-opacity="1"/></filter>
  <filter id="vGlow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="16"/></filter>
</defs>`;
function menuIcon(tint, glyph) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">${VDEFS}
  <circle cx="128" cy="128" r="84" fill="${tint}" opacity=".55" filter="url(#vGlow)"/>
  <g filter="url(#vShadow)"><g stroke="${VG}" stroke-width="10" stroke-linejoin="round" stroke-linecap="round">${glyph}</g></g>
</svg>`;
}
// White shine strokes (no outline) laid over a shape.
const shine = d => `<path d="${d}" fill="none" stroke="#fff" stroke-opacity=".8" stroke-width="9"/>`;

const MENU = {
  // Treasure chest with a rift crystal on the lid.
  Store: ['#ff4d6d', `<path d="M40 120 h176 v86 q0 12 -12 12 h-152 q-12 0 -12 -12z" fill="url(#vRed)"/>
    <path d="M40 124 q0 -62 88 -62 q88 0 88 62z" fill="url(#vRed)"/>
    <path d="M84 66 v152 M172 66 v152" fill="none" stroke="url(#vGold)" stroke-width="18"/>
    <path d="M84 66 v152 M172 66 v152" fill="none" stroke-width="0"/>
    <path d="M36 118 h184 v22 h-184z" fill="url(#vGold)"/>
    <rect x="110" y="128" width="36" height="42" rx="6" fill="url(#vGold)"/><circle cx="128" cy="146" r="6" fill="${VG}" stroke="none"/>
    <path d="M128 14 L150 50 L128 82 L106 50Z" fill="url(#vViolet)"/>
    <g stroke="none">${shine('M60 104 q6 -26 34 -34')}${shine('M120 30 l-6 18')}</g>`],
  // Backpack with a gold buckle.
  Items: ['#38a3ff', `<path d="M96 52 q0 -30 32 -30 q32 0 32 30" fill="none" stroke-width="16"/>
    <path d="M96 52 q0 -30 32 -30 q32 0 32 30" fill="none" stroke="#7fc6ff" stroke-width="6"/>
    <path d="M52 92 q0 -40 40 -40 h72 q40 0 40 40 v108 q0 18 -18 18 h-116 q-18 0 -18 -18z" fill="url(#vBlue)"/>
    <path d="M52 112 q76 34 152 0 v-20 q0 -40 -40 -40 h-72 q-40 0 -40 40z" fill="#1d6fd6"/>
    <rect x="82" y="146" width="92" height="56" rx="12" fill="#1d6fd6"/>
    <rect x="112" y="116" width="32" height="30" rx="6" fill="url(#vGold)"/>
    <g stroke="none">${shine('M70 96 q4 -22 26 -28')}</g>`],
  // Bounty scroll with a big "!".
  Quests: ['#ff9f1c', `<path d="M60 44 h136 v168 h-136z" fill="url(#vPaper)"/>
    <rect x="40" y="26" width="176" height="30" rx="15" fill="url(#vWood)"/>
    <rect x="40" y="200" width="176" height="30" rx="15" fill="url(#vWood)"/>
    <path d="M112 70 h32 l-6 82 h-20z" fill="url(#vOrange)"/><circle cx="128" cy="180" r="15" fill="url(#vOrange)"/>
    <g stroke="none">${shine('M58 34 h60')}${shine('M120 80 l2 40')}</g>`],
  // Gold compass with a red and white needle.
  Areas: ['#2fd37a', `<circle cx="128" cy="128" r="96" fill="url(#vGold)"/>
    <circle cx="128" cy="128" r="74" fill="url(#vGreen)"/>
    <path d="M128 44 L150 128 L128 212 L106 128Z" fill="#fff"/>
    <path d="M128 44 L150 128 H106Z" fill="url(#vRed)"/>
    <circle cx="128" cy="128" r="14" fill="url(#vGold)"/>
    <g stroke="none">${shine('M64 92 q14 -30 46 -40')}</g>`],
  // Rift portal with a sword through it.
  Play: ['#a855f7', `<ellipse cx="128" cy="134" rx="80" ry="98" fill="url(#vViolet)"/>
    <ellipse cx="128" cy="134" rx="52" ry="68" fill="#2a0d5c"/>
    <ellipse cx="128" cy="134" rx="26" ry="38" fill="#e7c8ff" stroke="none"/>
    <path d="M58 206 L184 56 l20 -6 l-6 20 L72 220z" fill="url(#vSteel)"/>
    <path d="M52 178 l46 46" fill="none" stroke-width="22"/><path d="M52 178 l46 46" fill="none" stroke="url(#vGold)" stroke-width="10"/>
    <path d="M58 222 l-18 18" fill="none" stroke-width="18"/><path d="M58 222 l-18 18" fill="none" stroke="#7a4a22" stroke-width="7"/>
    <g stroke="none">${shine('M76 82 q18 -34 50 -44')}</g>`],
  // Hooded riftwalker with glowing eyes.
  Profile: ['#4f7dff', `<path d="M128 28 q70 0 78 84 q4 44 -20 62 h-116 q-24 -18 -20 -62 q8 -84 78 -84z" fill="url(#vNavy)"/>
    <ellipse cx="128" cy="118" rx="40" ry="46" fill="${VG}"/>
    <circle cx="112" cy="116" r="9" fill="#8fe3ff" stroke="none"/><circle cx="144" cy="116" r="9" fill="#8fe3ff" stroke="none"/>
    <path d="M36 230 q8 -66 92 -66 q84 0 92 66z" fill="url(#vBlue)"/>
    <path d="M128 168 L144 194 L128 222 L112 194Z" fill="url(#vGold)"/>
    <g stroke="none">${shine('M70 80 q12 -32 44 -42')}</g>`],
  // Calendar page with a gold star day.
  Calendar: ['#ffc83d', `<path d="M40 62 h176 v146 q0 14 -14 14 h-148 q-14 0 -14 -14z" fill="#fffaf0"/>
    <path d="M40 62 h176 v42 h-176z" fill="url(#vRed)"/>
    <path d="M84 40 v42 M172 40 v42" fill="none" stroke-width="20"/><path d="M84 40 v42 M172 40 v42" fill="none" stroke="url(#vSteel)" stroke-width="8"/>
    <path d="M66 134 h124 M66 164 h124 M66 194 h124 M97 114 v96 M128 114 v96 M159 114 v96" fill="none" stroke="#c9c0d8" stroke-width="5"/>
    <path d="M174 122 l9 18 20 3 -14 14 3 20 -18 -9 -18 9 3 -20 -14 -14 20 -3z" fill="url(#vGold)" stroke-width="7"/>
    <g stroke="none">${shine('M56 76 h50')}</g>`],
};

// ---------------------------------------------------------------------------
// Particle / VFX textures. White on transparent so ParticleEmitter.Color,
// Beam.Color and Decal.Color3 can tint them per element.
// ---------------------------------------------------------------------------
function fxSvg(w, h, body, defs = '') {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs>${defs}</defs>${body}</svg>`;
}
const FX = {
  // Soft round glow.
  fx_glow: fxSvg(256, 256, `<circle cx="128" cy="128" r="124" fill="url(#g)"/>`,
    `<radialGradient id="g"><stop offset="0" stop-color="#fff"/><stop offset=".25" stop-color="#fff" stop-opacity=".85"/><stop offset=".6" stop-color="#fff" stop-opacity=".25"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`),
  // Long thin streak (for sparks, wind, speed lines). Use with Orientation VelocityParallel.
  fx_spark: fxSvg(256, 256, `<ellipse cx="128" cy="128" rx="14" ry="122" fill="url(#g)"/><ellipse cx="128" cy="128" rx="5" ry="90" fill="#fff"/>`,
    `<radialGradient id="g"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`),
  // Crescent wind blade: a thick curved slash that fades out at both tips.
  fx_crescent: fxSvg(256, 256, `<path d="M28 168 C60 70 196 70 228 168 C190 118 66 118 28 168Z" fill="url(#g)"/>
      <path d="M44 160 C84 96 172 96 212 160" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-opacity=".9"/>`,
    `<linearGradient id="g" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".3" stop-color="#fff" stop-opacity=".8"/><stop offset=".5" stop-color="#fff"/><stop offset=".7" stop-color="#fff" stop-opacity=".8"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>`),
  // Shockwave ring with a hot inner edge.
  fx_ring: fxSvg(512, 512, `<circle cx="256" cy="256" r="232" fill="none" stroke="url(#g)" stroke-width="40"/><circle cx="256" cy="256" r="246" fill="none" stroke="#fff" stroke-width="5"/>`,
    `<radialGradient id="g" r=".5"><stop offset=".78" stop-color="#fff" stop-opacity="0"/><stop offset=".9" stop-color="#fff" stop-opacity=".7"/><stop offset=".97" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`),
  // Telegraph circle: dashed outer ring + faint fill + rune ticks.
  fx_telegraph: fxSvg(512, 512, `<circle cx="256" cy="256" r="236" fill="#fff" fill-opacity=".12"/>
    <circle cx="256" cy="256" r="236" fill="none" stroke="#fff" stroke-width="10" stroke-dasharray="38 18"/>
    <circle cx="256" cy="256" r="200" fill="none" stroke="#fff" stroke-width="3" opacity=".6"/>
    ${Array.from({ length: 12 }, (_, i) => { const a = i / 12 * Math.PI * 2; const x1 = 256 + Math.cos(a) * 205, y1 = 256 + Math.sin(a) * 205, x2 = 256 + Math.cos(a) * 225, y2 = 256 + Math.sin(a) * 225; return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="#fff" stroke-width="7"/>`; }).join('')}`),
  // Soft flame with three licking tongues (tallest in the middle), a hot
  // core near the base and gently warped, feathered edges. Points up.
  fx_flame: fxSvg(256, 256, `<g filter="url(#warp)">
      <path d="M128 10 C138 60 158 78 164 110 C172 92 174 74 170 56 C196 92 210 128 204 168 C198 214 166 246 128 246 C90 246 58 214 52 168 C46 128 60 92 86 56 C82 74 84 92 92 110 C98 78 118 60 128 10Z" fill="url(#outer)"/>
      <path d="M128 92 C136 124 160 140 160 178 C160 212 146 234 128 234 C110 234 96 212 96 178 C96 140 120 124 128 92Z" fill="url(#inner)"/>
    </g>`,
    `<linearGradient id="outer" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".25" stop-color="#fff" stop-opacity=".55"/><stop offset=".7" stop-color="#fff" stop-opacity=".9"/><stop offset="1" stop-color="#fff" stop-opacity=".75"/></linearGradient>
     <radialGradient id="inner" cx=".5" cy=".75" r=".55"><stop offset="0" stop-color="#fff"/><stop offset=".65" stop-color="#fff" stop-opacity=".7"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
     <filter id="warp" x="-20%" y="-20%" width="140%" height="140%">
       <feTurbulence type="fractalNoise" baseFrequency=".012 .03" numOctaves="2" seed="4" result="n"/>
       <feDisplacementMap in="SourceGraphic" in2="n" scale="22" xChannelSelector="R" yChannelSelector="G" result="d"/>
       <feGaussianBlur in="d" stdDeviation="3"/>
     </filter>`),
  // Puffy smoke blob with soft noise.
  fx_smoke: fxSvg(256, 256, `<g filter="url(#n)"><circle cx="128" cy="138" r="80" fill="url(#g)"/><circle cx="88" cy="120" r="56" fill="url(#g)"/><circle cx="170" cy="112" r="60" fill="url(#g)"/><circle cx="130" cy="86" r="54" fill="url(#g)"/></g>`,
    `<radialGradient id="g"><stop offset="0" stop-color="#fff" stop-opacity=".9"/><stop offset=".7" stop-color="#fff" stop-opacity=".45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
     <filter id="n"><feTurbulence type="fractalNoise" baseFrequency=".03" numOctaves="3" seed="3"/><feDisplacementMap in="SourceGraphic" scale="26"/></filter>`),
  // Horizontal jagged lightning, tileable along X (for Beams).
  fx_lightning: fxSvg(512, 128, `<g filter="url(#gl)"><polyline points="0,64 40,40 70,82 110,30 150,90 190,50 230,74 270,24 310,96 350,46 390,80 430,36 470,70 512,64" fill="none" stroke="#fff" stroke-width="10" stroke-linejoin="bevel"/></g>
    <polyline points="0,64 40,40 70,82 110,30 150,90 190,50 230,74 270,24 310,96 350,46 390,80 430,36 470,70 512,64" fill="none" stroke="#fff" stroke-width="4"/>
    <polyline points="110,30 120,8 128,20 M310,96 322,118" fill="none" stroke="#fff" stroke-width="3"/>`,
    `<filter id="gl" x="-10%" y="-50%" width="120%" height="200%"><feGaussianBlur stdDeviation="7"/></filter>`),
  // Curved wind swirl arc.
  fx_swirl: fxSvg(256, 256, `<path d="M40 150 C40 70 150 40 200 92 C232 126 206 180 160 176 C124 172 118 132 146 124" fill="none" stroke="url(#g)" stroke-width="16" stroke-linecap="round"/>`,
    `<linearGradient id="g" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity=".8"/><stop offset="1" stop-color="#fff"/></linearGradient>`),
  // Water droplet.
  fx_drop: fxSvg(256, 256, `<path d="M128 24 C150 84 196 120 196 168 C196 210 166 236 128 236 C90 236 60 210 60 168 C60 120 106 84 128 24Z" fill="#fff" fill-opacity=".85"/><path d="M100 150 C100 126 112 112 124 104" fill="none" stroke="#fff" stroke-width="12" stroke-linecap="round"/>`),
  // Ground cracks decal (white, tinted per element).
  fx_crack: fxSvg(512, 512, `<g fill="none" stroke="#fff" stroke-linecap="round" stroke-linejoin="round">
    <path d="M256 256 L210 180 L224 120 L180 40 M256 256 L340 210 L400 222 L480 170 M256 256 L300 330 L286 400 L330 480 M256 256 L170 290 L120 270 L40 320 M224 120 L270 90 M300 330 L360 350 M170 290 L160 350" stroke-width="12"/>
    <path d="M256 256 L210 180 L224 120 L180 40 M256 256 L340 210 L400 222 L480 170 M256 256 L300 330 L286 400 L330 480 M256 256 L170 290 L120 270 L40 320" stroke-width="30" stroke-opacity=".25"/></g>
    <circle cx="256" cy="256" r="40" fill="url(#g)"/>`,
    `<radialGradient id="g"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`),
  // Crystal shard.
  fx_shard: fxSvg(256, 256, `<polygon points="128,10 168,100 140,246 100,120" fill="#fff" fill-opacity=".9"/><polygon points="128,10 140,246 100,120" fill="#fff" fill-opacity=".55"/>`),
};

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
ASSETS.item_RiftShard = { w: 256, h: 256, svg: relic('#b9a68f', ITEM_GLYPH.RiftShard) };
ASSETS.item_HuskIchor = { w: 256, h: 256, svg: relic('#6fd38a', ITEM_GLYPH.HuskIchor) };
ASSETS.item_EmberCore = { w: 256, h: 256, svg: relic('#5aa8ff', ITEM_GLYPH.EmberCore) };
ASSETS.bag = { w: 256, h: 256, svg: relic('#e9c27a', BAG_GLYPH) };
ASSETS.stat_Vitality = { w: 256, h: 256, svg: relic('#e8364a', STAT_GLYPH.Vitality) };
ASSETS.stat_Might = { w: 256, h: 256, svg: relic('#ff8a3a', STAT_GLYPH.Might) };
ASSETS.stat_Swiftness = { w: 256, h: 256, svg: relic('#9ff0d8', STAT_GLYPH.Swiftness) };
ASSETS.stat_Focus = { w: 256, h: 256, svg: relic('#b26cff', STAT_GLYPH.Focus) };
for (const [id, [tint, glyph]] of Object.entries(MENU)) {
  ASSETS['menu_' + id] = { w: 256, h: 256, svg: menuIcon(tint, glyph) };
}
for (const [name, svg] of Object.entries(FX)) {
  const m = svg.match(/width="(\d+)" height="(\d+)"/);
  ASSETS[name] = { w: Number(m[1]), h: Number(m[2]), svg };
}

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
