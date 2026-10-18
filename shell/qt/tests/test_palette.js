const fs = require("fs")
const src = fs.readFileSync(require("path").join(__dirname, "../theme/Palette.js"), "utf8").replace(/^\.pragma library\n/, "")
const m = { exports: {} }; new Function("module", src)(m)
const { build, contrast, parseHex } = m.exports
const seeds = ["#6750A4","#000000","#ffffff","#ffff00","#00ff00","#ff0000","#808080","#0061A4","#B3261E","#006A6A","#7D5700","#00ffff","#ff00ff","#80ff0000","bad","","#fff"]
const surf = ["surface","surfaceContainerLowest","surfaceContainerLow","surfaceContainer","surfaceContainerHigh","surfaceContainerHighest"]
const checks = []
for (const s of seeds) for (const dark of [true,false]) {
  const p = build(s, dark), tag = `${s||"(empty)"}/${dark?"dark":"light"}`
  for (const k of Object.keys(p)) if (k !== "dark" && !/^#[0-9a-f]{6}$/.test(p[k])) throw new Error(`invalid ${k}=${p[k]} for ${tag}`)
  for (const sf of surf) { checks.push([tag,"fg/"+sf,contrast(p.fg,p[sf]),4.5]); checks.push([tag,"fgMuted/"+sf,contrast(p.fgMuted,p[sf]),4.5]) }
  for (const sf of ["surfaceContainer","surfaceContainerHigh","surfaceContainerHighest"]) checks.push([tag,"primaryText/"+sf,contrast(p.primaryText,p[sf]),4.5-0.0])
  for (const k of ["primary","secondary","tertiary","error"]) checks.push([tag,k+"Fg",contrast(p[k+"Fg"],p[k]),4.5])
  for (const k of ["primary","secondary","tertiary","error"]) checks.push([tag,k+"ContainerFg",contrast(p[k+"ContainerFg"],p[k+"Container"]),4.5])
  checks.push([tag,"outline/highest",contrast(p.outline,p.surfaceContainerHighest),3])
  checks.push([tag,"primary/containerHigh (UI)",contrast(p.primary,p.surfaceContainerHigh),3])
  checks.push([tag,"primary/secContainer (slider)",contrast(p.primary,p.secondaryContainer),1.5])
}
const bad = checks.filter(c => c[2] < c[3] - 1e-9)
console.log("checks:", checks.length, " failures:", bad.length)
bad.slice(0,25).forEach(c => console.log("FAIL", c[0], c[1], c[2].toFixed(2), "<", c[3]))
const mins = {}; checks.forEach(c => { const k=c[1].replace(/\/.*/,""); mins[k]=Math.min(mins[k]??99,c[2]) })
console.log("min contrast per pair-type:", Object.fromEntries(Object.entries(mins).map(([k,v])=>[k,+v.toFixed(2)])))
const d=build("#6750A4",true); console.log("sample dark:", {surface:d.surface,fg:d.fg,primary:d.primary,primaryFg:d.primaryFg})
