.pragma library
// Pure-JS Material-3-style palette generator. No Qt color objects are used,
// so nothing can silently collapse to black: every output is a validated
// "#rrggbb" string, and every foreground is chosen by measured contrast.

var FALLBACK_SEED = "#6750A4"

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

function parseHex(str) {
    var s = ("" + str).trim().replace(/^#/, "")
    if (s.length === 8) s = s.slice(2)               // #aarrggbb -> rrggbb
    if (s.length === 3) s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2]
    if (!/^[0-9a-fA-F]{6}$/.test(s)) return null
    return { r: parseInt(s.slice(0, 2), 16) / 255,
             g: parseInt(s.slice(2, 4), 16) / 255,
             b: parseInt(s.slice(4, 6), 16) / 255 }
}

function toHsl(c) {
    var max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b)
    var h = 0, s = 0, l = (max + min) / 2, d = max - min
    if (d !== 0) {
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
        if (max === c.r) h = ((c.g - c.b) / d) % 6
        else if (max === c.g) h = (c.b - c.r) / d + 2
        else h = (c.r - c.g) / d + 4
        h *= 60
        if (h < 0) h += 360
    }
    return { h: h, s: s, l: l }
}

function hex2(v) {
    var n = Math.round(clamp(isFinite(v) ? v : 0, 0, 1) * 255)
    return (n < 16 ? "0" : "") + n.toString(16)
}

function hsl(h, s, l) {                               // -> "#rrggbb"
    h = ((h % 360) + 360) % 360; s = clamp(s, 0, 1); l = clamp(l, 0, 1)
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q
    function f(t) {
        if (t < 0) t += 1
        if (t > 1) t -= 1
        if (t < 1 / 6) return p + (q - p) * 6 * t
        if (t < 1 / 2) return q
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
        return p
    }
    return "#" + hex2(f(h / 360 + 1 / 3)) + hex2(f(h / 360)) + hex2(f(h / 360 - 1 / 3))
}

function luminance(hex) {
    var c = parseHex(hex)
    function lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
}

function contrast(a, b) {
    var la = luminance(a), lb = luminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

// Foreground for a background: tinted near-white or near-black, whichever
// measures better; pure white/black as the last resort. Always >= 4.5:1.
function onColor(bg, h, s) {
    var light = hsl(h, s * 0.25, 0.97), dark = hsl(h, s * 0.35, 0.09)
    var best = contrast(light, bg) >= contrast(dark, bg) ? light : dark
    if (contrast(best, bg) >= 4.5) return best
    return contrast("#ffffff", bg) >= contrast("#000000", bg) ? "#ffffff" : "#000000"
}

// Nudge a color's lightness until it has >= ratio contrast against bg.
function ensure(color, bg, ratio, h, s) {
    var hsl0 = toHsl(parseHex(color)), l = hsl0.l, up = luminance(bg) < 0.5
    for (var i = 0; i < 40 && contrast(hsl(h, s, l), bg) < ratio; i++)
        l = clamp(l + (up ? 0.02 : -0.02), 0, 1)
    return hsl(h, s, l)
}

function build(seedStr, dark) {
    var seed = parseHex(seedStr) || parseHex(FALLBACK_SEED)
    var base = toHsl(seed)
    var h = base.h
    var chroma = base.s < 0.08 ? 0 : clamp(base.s, 0.30, 0.85)   // grey seeds stay grey
    var sec = chroma === 0 ? 0 : clamp(chroma * 0.30, 0.10, 0.28)
    var ter = chroma === 0 ? 0 : clamp(chroma * 0.60, 0.25, 0.60)
    var th = h + 60
    var n = chroma === 0 ? 0 : 0.07, nv = chroma === 0 ? 0 : 0.11

    var p = {}
    p.dark = dark
    p.seed = hsl(h, chroma, 0.5)

    // surfaces
    p.surface                 = hsl(h, n, dark ? 0.065 : 0.98)
    p.surfaceContainerLowest  = dark ? hsl(h, n, 0.04) : "#ffffff"
    p.surfaceContainerLow     = hsl(h, n, dark ? 0.10  : 0.96)
    p.surfaceContainer        = hsl(h, n, dark ? 0.125 : 0.94)
    p.surfaceContainerHigh    = hsl(h, n, dark ? 0.165 : 0.92)
    p.surfaceContainerHighest = hsl(h, n, dark ? 0.21  : 0.895)

    // text on surfaces
    p.fg      = hsl(h, n * 0.6, dark ? 0.91 : 0.10)
    p.fgMuted = hsl(h, nv,      dark ? 0.80 : 0.30)
    p.outline        = ensure(hsl(h, nv, dark ? 0.62 : 0.46), p.surfaceContainerHighest, 3, h, nv)
    p.outlineVariant = hsl(h, nv, dark ? 0.30 : 0.80)

    // accents
    p.primary            = ensure(hsl(h, chroma, dark ? 0.80 : 0.40), p.surfaceContainerHighest, 3, h, chroma)
    p.primaryContainer   = hsl(h, chroma * 0.85, dark ? 0.30 : 0.90)
    p.secondary          = hsl(h, sec, dark ? 0.80 : 0.40)
    p.secondaryContainer = hsl(h, sec, dark ? 0.30 : 0.90)
    p.tertiary           = ensure(hsl(th, ter, dark ? 0.80 : 0.40), p.surfaceContainerHighest, 3, th, ter)
    p.tertiaryContainer  = hsl(th, ter, dark ? 0.30 : 0.90)
    p.error              = dark ? "#ffb4ab" : "#ba1a1a"
    p.errorContainer     = dark ? "#93000a" : "#ffdad6"

    // foregrounds, measured
    p.primaryFg            = onColor(p.primary, h, chroma)
    p.primaryContainerFg   = onColor(p.primaryContainer, h, chroma)
    p.secondaryFg          = onColor(p.secondary, h, sec)
    p.secondaryContainerFg = onColor(p.secondaryContainer, h, sec)
    p.tertiaryFg           = onColor(p.tertiary, th, ter)
    p.tertiaryContainerFg  = onColor(p.tertiaryContainer, th, ter)
    p.errorFg              = onColor(p.error, 4, 0.5)
    p.errorContainerFg     = onColor(p.errorContainer, 4, 0.5)

    // accent used as *text or icon* on surfaces must also be readable
    p.primaryText = ensure(p.primary, p.surfaceContainerHighest, 4.5, h, chroma)
    return p
}

function withAlpha(hex, a) {                         // "#rrggbb" + alpha -> "#aarrggbb"
    return "#" + hex2(a) + hex.replace("#", "")
}

if (typeof module !== "undefined") module.exports = { build: build, contrast: contrast, parseHex: parseHex }
