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
import {barsOption, matrixOption, examOption, ablationOption, examProfileOption} from "./dronex_charts.js"

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

// ⚠ A COLOUR IS NOT A STRING. ECharts normalises `#e2556e` to
// `rgb(226,85,110)` on the way to SVG, so matching the hex finds nothing even
// when the mark is painted exactly right. This caught the checker out the first
// time it was pointed at a heatmap.
const paints = (svg, hex) => {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16))
  return svg.includes(hex) || svg.includes(`rgb(${r},${g},${b})`)
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

// ⚠ THE CELLS, NOT THE INTENT. Read what ECharts was actually handed.
const cells = matrix.series[0].data
check("one cell per fought or in-flight route", cells.length === matrixSpec.cells.length)

// Hue is direction: a route won outright must land at an end of the scale.
const wonAll = cells[matrixSpec.cells.findIndex((c) => c.of === "msi00 → beam03")]
const lostAll = cells[matrixSpec.cells.findIndex((c) => c.of === "beam01 → beam00")]
check("a route won outright sits at the raider end", wonAll.value[2] === 100, `${wonAll.value[2]}`)
check("a route lost outright sits at the island end", lostAll.value[2] === 0, `${lostAll.value[2]}`)

// ⚠ OPACITY IS CONFIDENCE. One raid won is 100% and must not shout.
const thin = cells[matrixSpec.cells.findIndex((c) => c.of === "beam00 → beam01")]
check("a one-raid route is faded, not shouting", thin.itemStyle.opacity < 0.5, `${thin.itemStyle.opacity}`)
check("a well-fought route is at full strength",
  cells[matrixSpec.cells.findIndex((c) => c.of === "beam00 → beam02")].itemStyle.opacity === 1)

// ⚠⚠ THE MIDPOINT IS NEUTRAL. A hue in the middle would claim a lean that is not
// there; grey is the only honest colour for "neither side".
check("the scale is two hues around a neutral middle",
  matrix.visualMap.inRange.color.length === 3 &&
    matrix.visualMap.inRange.color[1] === SIDES.draw,
  matrix.visualMap.inRange.color.join(","))

// The failure that produced the invisible tint: the fill must actually be painted.
check("cells are painted in the side colours", paints(msvg, SIDES.attacker) && paints(msvg, SIDES.defender))
check("nothing rendered at NaN", !/NaN/.test(msvg))
check("the grid drew something", msvg.length > 2000, `${msvg.length} bytes`)

// The count is a number on the cell, never an area to judge.
check("every route shows its raid count", matrix.series[0].label.show === true)
check("no circles are drawn at all",
  !JSON.stringify(matrix).includes('"pie"') && !(matrix.graphic || []).some((g) => g.type === "circle"))

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
check("bars are painted", paints(bsvg, SIDES.attacker) && paints(bsvg, SIDES.defender))
check("bars rendered without NaN", !/NaN/.test(bsvg))

// A spec this build does not understand must draw nothing rather than throw.
console.log("exam")
const RAMP = ["#8ab8dc", "#0f3d61"]
const examSpec = {
  rungs: 6,
  sat: 3,
  columns: [1, 2, 3, 4],
  cells: [0, 1, 2, 3].flatMap((x) =>
    [96, 98, 97, 44, 50, 85].map((rate, y) => ({x, y, rate: x === 3 ? Math.max(0, rate - 40) : rate}))
  )
}
const exam = examOption({spec: examSpec, ramp: RAMP, text: INK})
const esvg = render(exam)

check("every rung gets a row", exam.yAxis.data.length === 6)
check("every sample gets a column", exam.series[0].data.length === 24, `${exam.series[0].data.length} cells`)
check("the scale is a magnitude, 0 to 100", exam.visualMap.min === 0 && exam.visualMap.max === 100)
// ⚠ A DRILL HAS NO RAIDER AND NO ISLAND. Lending it a side hue would say it did.
check("the exam never uses a side colour",
  !paints(esvg, SIDES.attacker) && !paints(esvg, SIDES.defender))
check("the heatmap drew cells", !/NaN/.test(esvg) && esvg.length > 2000, `${esvg.length} bytes`)
check("an island with no vector draws nothing",
  examOption({spec: {rungs: 0, cells: [], columns: [], sat: 0}, ramp: RAMP, text: INK}) === null)

console.log("ablation")
const ablSpec = {
  at: [1, 2, 3, 4, 5],
  series: [
    {name: "air", data: [0, 25, 25, -25, 0]},
    {name: "ground", data: [0, 0, 0, 0, 0]},
    {name: "both", data: [25, 25, 50, 25, 25]}
  ]
}
const abl = ablationOption({spec: ablSpec, colour: ["#2a6fb0", "#d55e00", "#009e73"], text: INK})
const asvg = render(abl)

check("the axis is symmetric about zero", abl.yAxis.min === -abl.yAxis.max, `${abl.yAxis.min}..${abl.yAxis.max}`)
check("zero is drawn", abl.series.every((s) => s.markLine.data[0].yAxis === 0))
// ⚠ STEPS, NOT SLOPES. The wire republishes one exercise until the next is run.
check("readings are steps, not interpolated slopes", abl.series.every((s) => s.step === "end"))
check("the ablation never uses a side colour",
  !paints(asvg, SIDES.attacker) && !paints(asvg, SIDES.defender))
check("lines rendered without NaN", !/NaN/.test(asvg))
check("no readings draws nothing", ablationOption({spec: {at: [], series: []}, colour: [], text: INK}) === null)

console.log("exam profiles")
const profSpec = {
  drills: ["hoverer", "orbiter", "evader", "chaser", "duellist", "sniper"],
  series: [
    {island: "beam00 8ddd", rates: [96, 98, 98, 44, 50, 85]},
    {island: "beam01 a6b1", rates: [50, 48, 56, 6, 21, 50]},
    {island: "beam02 60ac", rates: [90, 92, 92, 90, 92, 85]}
  ]
}
const prof = examProfileOption({spec: profSpec, colour: ["#2a6fb0", "#d55e00", "#009e73"], text: INK})
const psvg = render(prof)

// ⚠ ALWAYS 0 TO 100. An axis fitted to the data makes a fleet at 90-97% look as
// spread out as one at 6-98%.
check("the profile axis is the real ceiling, not the data range",
  prof.yAxis.min === 0 && prof.yAxis.max === 100, `${prof.yAxis.min}..${prof.yAxis.max}`)
check("the ladder keeps its difficulty order",
  prof.xAxis.data[0] === "hoverer" && prof.xAxis.data[5] === "sniper")
check("one series per island", prof.series.length === 3)
// An island is an identity, not a side.
check("the profile never uses a side colour",
  !paints(psvg, SIDES.attacker) && !paints(psvg, SIDES.defender))
check("bars rendered without NaN", !/NaN/.test(psvg))
check("nobody having sat it draws nothing",
  examProfileOption({spec: {drills: [], series: []}, colour: [], text: INK}) === null)

console.log("skew")
check("an unknown spec returns nothing", barsOption({spec: {kind: "something-new"}, colour: [], text: INK, fill: SIDES}) === null)
check("a matrix without cells returns nothing", matrixOption({spec: {kind: "matrix"}, fill: SIDES, text: INK, height: H}) === null)

console.log(failures === 0 ? "\nall chart checks passed" : `\n${failures} chart check(s) FAILED`)
process.exit(failures === 0 ? 0 : 1)
