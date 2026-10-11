"""
Batch generator for Riftbound's 38 Rune Catalog icons.
Supports:
  1. Google Gemini / Imagen 3 API (Google AI Studio key)
  2. Free Pollinations / Flux engine (no key required)

Usage:
  # Option 2 (Google Gemini / Imagen 3):
  python tools/art/batch_generate_runes.py --key YOUR_GEMINI_API_KEY

  # Option 1 (Free / No Key):
  python tools/art/batch_generate_runes.py --free
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import requests

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT_DIR = os.path.join(ROOT, "art", "runes")

STYLE_SUFFIX = (
    "2D stylized game art, simplified illustration, bold chunky linework, painterly shading. "
    "Low-detail readable shapes, isolated game icon on solid pure white background, no borders, no text, 1:1."
)

RUNES = [
    # Common (8)
    {
        "id": "Rune_Might",
        "name": "Rune of Might",
        "glyph": "Alpha (A)",
        "prompt": (
            "A heavy thick dark basalt PoE2-style chiseled runestone tablet with rough beveled rock edges, "
            "deeply engraved with a glowing golden Greek letter Alpha (A), radiant power fissures and glowing cracks. "
            "Dramatic golden-amber rim lighting, high-contrast radiant sun-yellow highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Expansion",
        "name": "Rune of Expansion",
        "glyph": "Epsilon (E)",
        "prompt": (
            "A wide broad flat granite PoE2-style runestone tablet with chiseled chipped edges, "
            "deeply engraved with a glowing Greek letter Epsilon (E), wide expanding concentric wave fissures. "
            "Dramatic warm amber-orange rim lighting, radiant golden-yellow highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Haste",
        "name": "Rune of Haste",
        "glyph": "Lambda (Λ)",
        "prompt": (
            "A sleek angular chiseled dark slate PoE2-style runestone tablet with sharp chipped facets, "
            "deeply carved with a glowing turquoise-cyan Greek letter Lambda (Λ), dynamic speed fissures. "
            "Dramatic mint-teal rim lighting, high-contrast radiant cyan highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Reach",
        "name": "Rune of Reach",
        "glyph": "Tau (T)",
        "prompt": (
            "A tall elongated chiseled dark granite PoE2-style runestone tablet, "
            "deeply engraved with a sharp glowing Greek letter Tau (T) pointing like a spearhead, straight energy trajectory fissures. "
            "Dramatic golden-yellow rim lighting, high-contrast radiant sun-white highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Impact",
        "name": "Rune of Impact",
        "glyph": "Beta (B)",
        "prompt": (
            "A chunky rugged fractured boulder PoE2-style runestone with heavy shattered stone facets, "
            "deeply engraved with a bold glowing Greek letter Beta (B), explosive shockwave impact cracks. "
            "Dramatic warm amber-ochre rim lighting, white-hot and deep orange concussive highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Lingering",
        "name": "Rune of Lingering",
        "glyph": "Eta (H)",
        "prompt": (
            "An ancient weathered petrified dark stone tablet in PoE2 style with ancient moss cracks, "
            "deeply engraved with an eternal glowing Greek letter Eta (H), smoldering embers and slow-burning mystical smoke fissures. "
            "Dramatic warm amber-bronze rim lighting, glowing persimmon-orange highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Prospector",
        "name": "Rune of the Prospector",
        "glyph": "Rho (P)",
        "prompt": (
            "A dense pyritic dark stone PoE2-style runestone embedded with chunky raw gold ore veins, "
            "deeply engraved with a gleaming Greek letter Rho (P), molten gold seams oozing through the carved rock. "
            "Dramatic bright golden rim lighting, radiant canary-yellow and lustrous bullion-gold highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_HeavyMass",
        "name": "Rune of Heavy Mass",
        "glyph": "Mu (M)",
        "prompt": (
            "An immense ultra-thick dark meteoric ironstone PoE2-style tablet with dense blunt edges, "
            "deeply incised with a heavy glowing Greek letter Mu (M), dense molten-lead fissures glowing within. "
            "Dramatic molten-copper rim lighting, dense bronze-orange highlights. " + STYLE_SUFFIX
        ),
    },

    # Rare (9)
    {
        "id": "Rune_Multishot",
        "name": "Rune of Multishot",
        "glyph": "Upsilon (Y)",
        "prompt": (
            "A three-pronged fan-shaped dark slate PoE2-style runestone tablet with chipped beveled edges, "
            "deeply carved with a splitting glowing Greek letter Upsilon (Y), forking triple energy trail fissures. "
            "Dramatic electric-blue rim lighting, radiant cerulean and cyan highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Piercing",
        "name": "Rune of Piercing",
        "glyph": "Iota (I)",
        "prompt": (
            "A sharp spear-pointed hexagonal dark flint PoE2-style runestone, "
            "deeply engraved with a piercing glowing Greek letter Iota (I), razor-sharp continuous energy beam line cutting through. "
            "Dramatic laser-cyan rim lighting, piercing arctic-blue highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Ricochet",
        "name": "Rune of Ricochet",
        "glyph": "Zeta (Z)",
        "prompt": (
            "A sharp zigzag-angled dark stone PoE2-style runestone tablet with chiseled corner facets, "
            "deeply engraved with a glowing Greek letter Zeta (Z), dynamic bouncing ricochet trajectory fissures. "
            "Dramatic cobalt-blue rim lighting, radiant electric-blue bouncing spark highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Precision",
        "name": "Rune of Precision",
        "glyph": "Phi (Φ)",
        "prompt": (
            "An angular chiseled dark obsidian PoE2-style runestone tablet with sharp diamond-beveled edges, "
            "deeply engraved with a glowing sapphire-blue Greek letter Phi (Φ), precise razor-sharp glowing crosshair fissures. "
            "Dramatic azure-blue rim lighting, radiant cobalt and electric-cyan highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Executioner",
        "name": "Rune of the Executioner",
        "glyph": "Chi (X)",
        "prompt": (
            "A brutal guillotine-faceted dark basalt PoE2-style runestone slab with chipped jagged edges, "
            "deeply incised with a glowing Greek letter Chi (X) resembling an executioner's mark. "
            "Dramatic crimson-blue rim lighting, blood-red and deep navy highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_GiantHunter",
        "name": "Rune of the Giant Hunter",
        "glyph": "Gamma (Γ)",
        "prompt": (
            "A colossal rugged mountain-crag PoE2-style runestone tablet with ancient weathered fissures, "
            "deeply engraved with a heavy glowing Greek letter Gamma (Γ) shaped like a giant-slayer cleaver. "
            "Dramatic royal-blue and gold rim lighting, titan-slaying cerulean highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_DeepChill",
        "name": "Rune of Deep Chill",
        "glyph": "Theta (Θ)",
        "prompt": (
            "A frozen chiseled cryo-slate PoE2-style runestone tablet with sharp crystalline ice-rock facets, "
            "deeply inscribed with a circular glowing Greek letter Theta (Θ), frostbite frost cracks spreading outward. "
            "Dramatic glacial ice-blue rim lighting, sub-zero frost-white and arctic-cyan highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Tremor",
        "name": "Rune of Tremor",
        "glyph": "Delta (Δ)",
        "prompt": (
            "A tectonic fault-line cracked granite PoE2-style runestone tablet with uneven jarring stone seams, "
            "deeply engraved with a trembling glowing Greek letter Delta (Δ), seismic vibration fissures. "
            "Dramatic topaz-amber rim lighting, radiant seismic-yellow and electric-gold highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Momentum",
        "name": "Rune of Momentum",
        "glyph": "Sigma (Σ)",
        "prompt": (
            "An aerodynamic swept-wing basalt PoE2-style runestone tablet with chiseled speed bevels, "
            "deeply engraved with a sharp glowing Greek letter Sigma (Σ), surging kinetic wind streaks etched along edges. "
            "Dramatic vibrant azure rim lighting, radiant cobalt and rushing cyan velocity highlights. " + STYLE_SUFFIX
        ),
    },

    # Epic (9)
    {
        "id": "Rune_Aftershock",
        "name": "Rune of the Aftershock",
        "glyph": "Omega (Ω)",
        "prompt": (
            "A heavy cracked impact-crater PoE2-style runestone tablet with concentric impact fractures, "
            "deeply engraved with a pulsing glowing Greek letter Omega (Ω), delayed secondary seismic shockwave ring. "
            "Dramatic vibrant amethyst-purple rim lighting, radiant violet and hot lavender detonation highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Graviton",
        "name": "Rune of the Graviton Vortex",
        "glyph": "Omega (Ω)",
        "prompt": (
            "A circular dark meteor rock PoE2-style runestone tablet with rough cracked edges, "
            "deeply engraved with a mystic Greek letter Omega (Ω) surrounded by a swirling spiral vortex carved into the stone. "
            "Dramatic deep amethyst-purple rim lighting, radiant violet and hot magenta highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_MagmaTrail",
        "name": "Rune of the Magma Trail",
        "glyph": "Pi (Π)",
        "prompt": (
            "A charred volcanic obsidian PoE2-style runestone tablet with blackened scorched edges, "
            "deeply engraved with a glowing Greek letter Pi (Π) forming a blazing pathway of burning molten lava cracks. "
            "Dramatic fiery-crimson rim lighting, glowing magma-orange and sun-yellow embers. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_TwinSpark",
        "name": "Rune of Twin Spark",
        "glyph": "Kappa (K)",
        "prompt": (
            "A twin-faceted dark granite PoE2-style runestone tablet with bifurcated split edges, "
            "deeply carved with a dual glowing Greek letter Kappa (K), twin electric lightning forks arcing across. "
            "Dramatic radiant violet-purple rim lighting, electric-lavender and neon-purple discharge highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_ThermalShock",
        "name": "Rune of Thermal Shock",
        "glyph": "Psi (Ψ)",
        "prompt": (
            "A bi-elemental cracked volcanic stone PoE2-style tablet split down the middle, "
            "deeply engraved with a glowing Greek letter Psi (Ψ), superheated explosive steam blast fissures erupting. "
            "Dramatic dual-tone magenta and steam-white rim lighting, thermal steam-cyan highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_OverloadedVoltage",
        "name": "Rune of Overloaded Voltage",
        "glyph": "Xi (Ξ)",
        "prompt": (
            "A lightning-scorched dark fulgurite PoE2-style runestone tablet with jagged crystalline fractures, "
            "deeply incised with a high-voltage glowing Greek letter Xi (Ξ), branching three-way electric arc fissures. "
            "Dramatic electric-violet rim lighting, radiant voltage-yellow and bright purple lightning sparks. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_BloodSiphon",
        "name": "Rune of the Blood Siphon",
        "glyph": "Phi (Φ)",
        "prompt": (
            "A dark hematite blood-stone PoE2-style runestone tablet with chipped razor-sharp edges, "
            "deeply engraved with a vampiric glowing Greek letter Phi (Φ), dark pulsing crimson life-vein fissures. "
            "Dramatic dark-ruby rim lighting, glowing sanguine-crimson and hot magenta highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_AegisWard",
        "name": "Rune of the Aegis Ward",
        "glyph": "Delta (Δ)",
        "prompt": (
            "A thick kite-shield shaped dark basalt PoE2-style runestone tablet with reinforced stone borders, "
            "deeply carved with a protective glowing Greek letter Delta (Δ), defensive barrier hexagonal mesh pattern. "
            "Dramatic deep-purple and gold rim lighting, radiant amethyst-shield highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Windrunner",
        "name": "Rune of the Windrunner",
        "glyph": "Lambda (Λ)",
        "prompt": (
            "A feather-crested aerodynamic dark slate PoE2-style runestone tablet with curved wind-carved bevels, "
            "deeply engraved with a soaring glowing Greek letter Lambda (Λ), dual cyclone whirlwind fissures. "
            "Dramatic ethereal violet-teal rim lighting, radiant lavender-wind and swift cyan highlights. " + STYLE_SUFFIX
        ),
    },

    # Legendary (12)
    {
        "id": "Rune_PhantomTwin",
        "name": "Rune of the Phantom Twin",
        "glyph": "Psi (Ψ)",
        "prompt": (
            "A mirrored dual-faced split obsidian PoE2-style runestone tablet with rough cleaved rock edges, "
            "deeply engraved with a soul-bound glowing Greek letter Psi (Ψ), an ethereal spectral clone phantom silhouette carved in energy. "
            "Dramatic legendary golden and spirit-cyan rim lighting, radiant ethereal ghost-blue highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_CelestialOrbit",
        "name": "Rune of the Celestial Orbit",
        "glyph": "Omicron (O)",
        "prompt": (
            "A spherical planetary dark meteor PoE2-style runestone tablet, "
            "deeply engraved with an ancient glowing Greek letter Omicron (O) encircled by glowing orbital planetary trajectory rings. "
            "Dramatic brilliant golden rim lighting, radiant starlight-yellow and solar-amber highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_ChainReaction",
        "name": "Rune of the Chain Reaction",
        "glyph": "Xi (Ξ)",
        "prompt": (
            "A heavily cracked fractured volcanic rock PoE2-style runestone tablet with violent jagged fissures splitting the stone, "
            "deeply engraved with a radiant glowing Greek letter Xi (Ξ), violent shockwave sparks and chain reaction burst cracks. "
            "Dramatic fiery golden-orange rim lighting, incandescent magma-yellow and hot crimson highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Singularity",
        "name": "Rune of the Singularity",
        "glyph": "Psi (Ψ)",
        "prompt": (
            "An ancient cracked void-black stone PoE2-style runestone tablet with chipped cosmic rock facets, "
            "deeply engraved with a radiant glowing Greek letter Psi (Ψ) in the center of an absorbing pitch-black void event horizon. "
            "Dramatic deep cosmic purple and gold rim lighting, radiant ultraviolet highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_EndlessCascade",
        "name": "Rune of the Endless Cascade",
        "glyph": "Ouroboros (O)",
        "prompt": (
            "A continuous infinity-loop carved dark granite PoE2-style runestone tablet with polished chipped facets, "
            "deeply engraved with an unbroken glowing Greek letter Ouroboros ring (O), cascading golden kinetic recharge sparks. "
            "Dramatic bright golden rim lighting, radiant canary-yellow highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_TripleCharge",
        "name": "Rune of the Triple Charge",
        "glyph": "Tri-Tier",
        "prompt": (
            "A stepped tripartite dark stone PoE2-style runestone slab featuring three carved stacked stone tiers, "
            "deeply engraved with three identical glowing golden Greek runes side-by-side, charged with ready power. "
            "Dramatic radiant gold rim lighting, tri-point incandescent yellow charge highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_DashWeaver",
        "name": "Rune of the Dash Weaver",
        "glyph": "Sigma (Σ)",
        "prompt": (
            "A forward-thrusting arrowhead shaped dark basalt PoE2-style runestone tablet, "
            "deeply engraved with a rushing glowing Greek letter Sigma (Σ), luminous dimensional warp threads weaving behind. "
            "Dramatic warp-gold and purple rim lighting, radiant golden weave threads. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_PrismaticPrism",
        "name": "Rune of the Prismatic Prism",
        "glyph": "Delta (Δ)",
        "prompt": (
            "A multi-faceted geometric crystal monolith PoE2-style runestone slab with razor-sharp prismatic facets, "
            "deeply engraved with a glowing Greek letter Delta (Δ), a full spectrum of refracted elemental rainbow light rays. "
            "Dramatic prismatic rainbow rim lighting, glowing ruby, emerald, sapphire, and amber highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_AbsoluteZero",
        "name": "Rune of Absolute Zero",
        "glyph": "Zeta (Z)",
        "prompt": (
            "An ancient dark permafrost ice-rock PoE2-style runestone tablet with sharp jagged frost shards, "
            "deeply engraved with a bone-chilling glowing Greek letter Zeta (Z), blinding crystalline absolute-zero shatter fractures. "
            "Dramatic blinding arctic-white and cyan rim lighting, zero-point frost-blue highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_Cataclysm",
        "name": "Rune of the Cataclysm",
        "glyph": "Omega (Ω)",
        "prompt": (
            "A colossal seismic-fault dark stone monolith PoE2-style tablet cracked wide open by catastrophic pressure, "
            "deeply engraved with a massive apocalyptic glowing Greek letter Omega (Ω), arena-shaking seismic volcanic energy. "
            "Dramatic cataclysmic molten-gold and magma-red rim lighting, incandescent sun-yellow highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_SpellTotem",
        "name": "Rune of the Spell-Totem",
        "glyph": "Pi (Π)",
        "prompt": (
            "A carved ancient dark stone rift-totem obelisk head in PoE2 style with weathered tribal notches, "
            "deeply engraved with a sacred glowing Greek letter Pi (Π) forming a shrine pillar, glowing mystical spirit eyes. "
            "Dramatic spiritual golden rim lighting, radiant ochre-gold and mystic amber beacon highlights. " + STYLE_SUFFIX
        ),
    },
    {
        "id": "Rune_BloodPact",
        "name": "Rune of the Blood Pact",
        "glyph": "Theta (Θ)",
        "prompt": (
            "A cursed obsidian sacrificial altar slab in PoE2 style stained with ancient dark ore, "
            "deeply engraved with a forbidden glowing Greek letter Theta (Θ), dark eldritch blood-covenant energy. "
            "Dramatic demonic crimson and unholy golden rim lighting, radiant blood-ruby highlights. " + STYLE_SUFFIX
        ),
    },
]


def generate_gemini(entry, api_key, out_path):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key={api_key}"
    payload = {
        "instances": [{"prompt": entry["prompt"]}],
        "parameters": {
            "sampleCount": 1,
            "aspectRatio": "1:1",
            "outputMimeType": "image/png",
        },
    }
    resp = requests.post(url, json=payload, timeout=60)
    if resp.status_code != 200:
        raise RuntimeError(f"HTTP {resp.status_code}: {resp.text}")
    data = resp.json()
    b64 = data["predictions"][0]["bytesBase64Encoded"]
    with open(out_path, "wb") as f:
        f.write(base64.b64decode(b64))


def generate_free(entry, out_path):
    encoded = urllib.parse.quote(entry["prompt"])
    url = f"https://image.pollinations.ai/prompt/{encoded}?width=512&height=512&nologo=true"
    resp = requests.get(url, timeout=60)
    if resp.status_code != 200:
        raise RuntimeError(f"HTTP {resp.status_code}")
    with open(out_path, "wb") as f:
        f.write(resp.content)


def main():
    parser = argparse.ArgumentParser(description="Batch generate Riftbound Rune Catalog icons.")
    parser.add_argument("--key", type=str, help="Google Gemini / AI Studio API key")
    parser.add_argument("--free", action="store_true", help="Use free Pollinations / FLUX engine (no key required)")
    parser.add_argument("--force", action="store_true", help="Overwrite existing images")
    args = parser.parse_args()

    api_key = args.key or os.environ.get("GEMINI_API_KEY")

    if not args.free and not api_key:
        print("\n=== Riftbound Rune Icon Batch Generator ===")
        print("Choose an option:")
        print("  1. Enter a Google Gemini API Key (Option 2 - Imagen 3 / Nano Banana)")
        print("  2. Type 'free' to generate without an API key (Option 1 - Pollinations FLUX)")
        choice = input("\nEnter API Key or 'free': ").strip()
        if choice.lower() == "free":
            args.free = True
        else:
            api_key = choice

    os.makedirs(OUT_DIR, exist_ok=True)
    engine_name = "Pollinations (Free FLUX)" if args.free else "Google Imagen 3 (Gemini / Nano Banana)"
    print(f"\n[Riftbound] Starting batch generation using {engine_name}...")
    print(f"[Riftbound] Output folder: {OUT_DIR}\n")

    total = len(RUNES)
    success = 0

    for i, entry in enumerate(RUNES, start=1):
        filename = f"{entry['id']}.jpg"
        out_path = os.path.join(OUT_DIR, filename)
        jpg_path = os.path.join(OUT_DIR, f"{entry['id']}.jpg")
        png_path = os.path.join(OUT_DIR, f"{entry['id']}.png")

        if (os.path.exists(jpg_path) or os.path.exists(png_path)) and not args.force:
            print(f"[{i}/{total}] SKIP (already exists): {entry['name']}")
            success += 1
            continue

        safe_glyph = entry['glyph'].encode('ascii', 'replace').decode('ascii')
        print(f"[{i}/{total}] Generating: {entry['name']} [{safe_glyph}]...", end="", flush=True)

        attempts = 0
        while attempts < 3:
            attempts += 1
            try:
                if args.free:
                    generate_free(entry, out_path)
                else:
                    generate_gemini(entry, api_key, out_path)
                print(" OK!")
                success += 1
                time.sleep(1.0)
                break
            except Exception as e:
                print(f" Retrying ({e})...", end="", flush=True)
                time.sleep(2)
        else:
            print(" FAILED.")

    print(f"\n[Riftbound] Completed! {success}/{total} runes saved in {OUT_DIR}.")


if __name__ == "__main__":
    main()
