// Render the /dronex charts for real, and measure them.
//
// ⚠ THIS EXISTS BECAUSE TWICE IN ONE AFTERNOON THIS PAGE SHIPPED A CHART THAT
// WAS ARITHMETICALLY CORRECT AND VISUALLY WRONG.
//
//   1. Ledger cells tinted with `color-mix(... 48%, transparent)` over a dark
//      surface. Exactly the CSS intended, indistinguishable from the background.
//      Seven unit tests passed on the numbers.
//   2. The in-flight marker: a 6-pixel radius scaled by a factor computed from
//      PERCENTAGES. A marker meant to annotate one cell was drawn across four
//      rows.
//
// Both were found by a human sending a screenshot. That is not a process, and
// "look at it before shipping" is an intention rather than a mechanism.
//
// ECharts renders SVG under Node, so the option a pure function builds can be
// rendered and the resulting geometry measured. These are the assertions a pair
// of eyes would have made.
//
// Run: node apps/beam_campus_web/assets/js/charts_check.mjs
import * as echarts from "../vendor/echarts.esm.js"
import {barsOption, matrixOption} from "./dronex_charts.js"

const W = 900
const H = 288

// The real tokens, so a change to the palette is checked against the real
// surface rather than against a stand-in.
const SIDES = {attacker: "#e2556e", defender: "#4c8dff", draw: "#8a8a86"}
const INK = "#e7e5e4"

let failures = 0
const check = (name, ok, detail) => {
  if (!ok) {
    failures += 1
    console.error(`  FAIL  ${name}${detail ? " — " + detail : ""}`)
  } else {
    console.log(`  ok    ${name}`)
  }
}

const render = (option) => {
  const chart = echarts.init(null, null, {renderer: "svg", ssr: true, width: W, height: H})
  chart.setOption({animation: false, ...option})
  const svg = chart.renderToSVGString()
  chart.dispose()
  return svg
}

// Five islands, a spread of raid counts including a route fought once and one
// route still out, which is the shape that broke twice.
const matrixSpec = {
  kind: "matrix",
  busiest: 9,
  rows: ["beam00 8ddd", "beam01 a6b1", "beam02 60ac", "beam03 e649", "msi00 d44f"],
  cols: ["beam00 8ddd", "beam01 a6b1", "beam02 60ac", "beam03 e649", "msi00 d44f"],
  cells: [
    {r: 0, c: 1, n: 1, a: 1, d: 0, x: 0, f: 0, of: "beam00 → beam01"},
    {r: 0, c: 2, n: 9, a: 5, d: 4, x: 0, f: 0, of: "beam00 → beam02"},
    {r: 1, c: 0, n: 4, a: 0, d: 4, x: 0, f: 0, of: "beam01 → beam00"},
    {r: 2, c: 0, n: 3, a: 2, d: 0, x: 1, f: 0, of: "beam02 → beam00"},
    {r: 3, c: 4, n: 0, a: 0, d: 0, x: 0, f: 1, of: "beam03 → msi00"},
    {r: 4, c: 3, n: 6, a: 6, d: 0, x: 0, f: 2, of: "msi00 → beam03"}
  ]
}

console.log("matrix")
const matrix = matrixOption({spec: matrixSpec, fill: SIDES, text: INK, height: H})
const msvg = render(matrix)

// ⚠ THE GEOMETRY, NOT THE INTENT. Read the radii ECharts actually drew.
const radii = matrix.series.map((s) => s.radius[1])
check("every ring is the same size", new Set(radii).size === 1, `radii ${[...new Set(radii)].join(",")}`)

const rowPx = (H * (100 - 14) / 100) / matrixSpec.rows.length
const outer = radii[0]
check("a ring fits inside its row", outer * 2 <= rowPx, `ring ${(outer * 2).toFixed(1)}px in a ${rowPx.toFixed(1)}px row`)

// The failure that produced the four-row striped circle.
const rings = (matrix.graphic || []).filter((g) => g.type === "circle")
check("an in-flight marker exists for every cell that has one", rings.length === 2, `${rings.length} rings`)
check(
  "an in-flight marker fits inside its row",
  rings.every((g) => g.shape.r * 2 <= rowPx),
  rings.map((g) => (g.shape.r * 2).toFixed(1) + "px").join(", ")
)
check("no marker is scaled by a unitless factor", rings.every((g) => !("scaleX" in g)))

// The failure that produced the invisible tint: a mark must actually be painted.
check("slices are painted in the side colours", msvg.includes(SIDES.attacker) && msvg.includes(SIDES.defender))
check("a route won outright still draws", msvg.split(SIDES.attacker).length - 1 >= 2)
check("nothing rendered at NaN", !/NaN/.test(msvg))
check("the grid drew something", msvg.length > 2000, `${msvg.length} bytes`)

// Every cell that has raids must produce a visible ring, and the count beside it.
const counts = (matrix.graphic || []).filter((g) => g.type === "text" && /^\d+$/.test(g.style.text))
check("every fought route shows its raid count", counts.length === 5, `${counts.length} counts`)

console.log("bars")
const barsSpec = {
  x_name: "ticks",
  y_name: "raids",
  categories: [0, 100, 200, 300],
  series: [
    {name: "raider won", role: "attacker", data: [0, 4, 7, 2]},
    {name: "island held", role: "defender", data: [1, 3, 2, 0]}
  ]
}
const bars = barsOption({spec: barsSpec, colour: ["#2a6fb0", "#d55e00"], text: INK, fill: SIDES})
const bsvg = render(bars)

check("a series with a role takes the convention, not the palette",
  bars.series[0].itemStyle.color === SIDES.attacker && bars.series[1].itemStyle.color === SIDES.defender,
  bars.series.map((s) => s.itemStyle.color).join(","))
check("bars are painted", bsvg.includes(SIDES.attacker) && bsvg.includes(SIDES.defender))
check("bars rendered without NaN", !/NaN/.test(bsvg))

// A spec this build does not understand must draw nothing rather than throw.
console.log("skew")
check("an unknown spec returns nothing", barsOption({spec: {kind: "something-new"}, colour: [], text: INK, fill: SIDES}) === null)
check("a matrix without cells returns nothing", matrixOption({spec: {kind: "matrix"}, fill: SIDES, text: INK, height: H}) === null)

console.log(failures === 0 ? "\nall chart checks passed" : `\n${failures} chart check(s) FAILED`)
process.exit(failures === 0 ? 0 : 1)
