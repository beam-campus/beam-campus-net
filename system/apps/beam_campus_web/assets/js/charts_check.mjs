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
import {readFileSync} from "node:fs"
import * as echarts from "../vendor/echarts.esm.js"
import {barsOption, matrixOption, examOption, ablationOption, examProfileOption, ratesOption, masterOption, tokens} from "./dronex_charts.js"

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

// ⚠⚠ A SPLIT, NOT A TINT, AND THE SPLIT IS WHAT THESE NOW MEASURE. The cell used
// to be one rectangle whose HUE encoded the balance, so a 60/40 route and a
// 55/45 route were two tints nobody could tell apart and a 50/50 route was the
// same grey as a route with too few raids to say. Each cell is now two segments
// whose LENGTHS carry the balance, which is the judgement a reader is good at.
const at = (of) => cells[matrixSpec.cells.findIndex((c) => c.of === of)]
const wonAll = at("msi00 → beam03")
const lostAll = at("beam01 → beam00")
check("a route won outright is all raider", wonAll[2] === 1, `${wonAll[2]}`)
check("a route lost outright is all island", lostAll[2] === 0, `${lostAll[2]}`)

// ⚠ OPACITY IS CONFIDENCE. One raid won is 100% and must not shout. It is
// applied inside renderItem now, so it is read off the rendered SVG rather than
// off an itemStyle the option no longer carries.
const thin = at("beam00 → beam01")
check("a one-raid route is drawn but not decided", thin[4] < 3, `${thin[4]} decided`)
check("a well-fought route is decided", at("beam00 → beam02")[4] >= 3)
check("the faded opacity reaches the svg", /opacity="0\.42"/.test(msvg))

// ⚠⚠ TWO SEGMENTS PER CELL, WHICH IS THE WHOLE CHANGE. Every route that has been
// fought draws an island part and a raider part, so the count of painted rects
// is at least two per cell rather than one.
// ⚠ BOTH NOTATIONS, BECAUSE A COLOUR IS NOT A STRING. ECharts may emit either
// the hex it was handed or the `rgb(r,g,b)` it normalised to, depending on the
// path a fill takes through the renderer. Counting only one form reported zero
// segments on a chart that was painting them correctly, which is the same trap
// `paints` above already carries a warning about.
const rects = (svg, hex) => {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16))
  const forms = [hex, `rgb(${r},${g},${b})`]
  return forms.reduce(
    (n, form) => n + (svg.split(`fill="${form}"`).length - 1),
    0
  )
}
check("every cell draws an island segment and a raider segment",
  rects(msvg, SIDES.defender) >= cells.length && rects(msvg, SIDES.attacker) >= cells.length,
  `${rects(msvg, SIDES.defender)} island, ${rects(msvg, SIDES.attacker)} raider, ${cells.length} cells`)

// ⚠⚠⚠⚠ THE WIDTHS, NOT THE PRESENCE OF A COLOUR, AND THE FIRST VERSION OF THIS
// CHECK MEASURED THE WRONG ONE. Collapsing the split so a single segment spans
// the whole cell still emits both fills — the second one merely has zero width —
// so every colour assertion above stayed green against a chart with no split in
// it at all. `renderItem` is a pure function of its api, so it can be called
// with a known cell and the two widths read off the shapes it returns.
const geometry = (share, decided) => {
  const api = {
    coord: () => [100, 50],
    size: () => [80, 40],
    value: (i) => [0, 0, share, 9, decided][i]
  }
  const [held, won] = matrix.series[0].renderItem({}, api).children
  return {held: held.shape.width, won: won.shape.width, opacity: held.style.opacity}
}

const balanced = geometry(0.5, 10)
check("a balanced route splits its cell in half",
  Math.abs(balanced.held - balanced.won) < 1,
  `island ${balanced.held}, raider ${balanced.won}`)

const swept = geometry(1, 10)
check("a route won outright gives the raider the whole cell",
  swept.held === 0 && swept.won > 70,
  `island ${swept.held}, raider ${swept.won}`)

const denied = geometry(0, 10)
check("a route lost outright gives the island the whole cell",
  denied.won === 0 && denied.held > 70,
  `island ${denied.held}, raider ${denied.won}`)

const lean = geometry(0.6, 10)
check("a 60/40 route is visibly lopsided, which a tint could never show",
  lean.won - lean.held > 10, `island ${lean.held}, raider ${lean.won}`)

check("an undecided route is faded", geometry(0.5, 1).opacity < 0.5)

// ⚠⚠⚠ AND NO HUE IS INTERPOLATED BETWEEN THEM ANY MORE. The old encoding ran a
// diverging scale through a neutral midpoint, so a balanced route and an
// undecided one shared a colour. There are exactly two fills now.
check("the two sides keep their own hues, never a blend",
  paints(msvg, SIDES.attacker) && paints(msvg, SIDES.defender) && !paints(msvg, SIDES.draw))
check("nothing rendered at NaN", !/NaN/.test(msvg))
check("no segment is drawn at negative width", !/width="-/.test(msvg))
check("the grid drew something", msvg.length > 2000, `${msvg.length} bytes`)

// The count is a number on the cell, never an area to judge, and it sits on the
// whole cell rather than inside a segment: a lopsided route has one segment a
// few pixels wide and a label placed in it would be clipped exactly where the
// split is most worth reading.
check("every route shows its raid count", (msvg.match(/<text/g) || []).length >= cells.length)

// ⚠ ROW `i' MUST BE COLUMN `i'. A category axis counts up from the bottom, so
// without inversion the self-raid blanks land on the anti-diagonal and every
// reading of the grid is transposed. Found by looking at a screenshot, which is
// why `scripts/look_at_the_page.sh` now exists.
check("the rows read top-down, so the diagonal is the diagonal", matrix.yAxis.inverse === true)
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

console.log("rates")
const ratesSpec = {
  bins: [0, 600000, 1200000],
  series: [
    {island: "beam00 8ddd", data: [4, 0, 7]},
    {island: "beam01 a6b1", data: [2, null, 3]}
  ]
}
const rates = ratesOption({spec: ratesSpec, colour: ["#2a6fb0", "#d55e00"], text: INK, label: "taken"})
const rsvg = render(rates)

check("one series per island", rates.series.length === 2)
// ⚠ A GAP IS NOT A ZERO. A bin with no samples must draw blank; a bar of height
// nought claims a measurement nobody made.
check("a missing bin stays null rather than becoming a zero",
  rates.series[1].data[1] === null)
check("a real zero is still drawn", rates.series[0].data[1] === 0)
check("bars are grouped, not stacked", rates.series.every((s) => !s.stack))
check("rates rendered without NaN", !/NaN/.test(rsvg))
check("no bins draws nothing", ratesOption({spec: {bins: [], series: []}, colour: [], text: INK}) === null)

// ⚠ THE MASTER PROFILE, WHERE THE ONLY READING IS A SHAPE. A level profile is
// progress and a profile falling away to the right is a treadmill, so the ONE
// thing this chart must never do is make those two look alike. Every assertion
// below reads a NUMBER back out of `renderItem`, never a colour: the matrix
// section above records what happened when a check asked whether both hues were
// painted, and stayed green against a chart with one segment at zero width.
console.log("master")
const CAT = ["#2a6fb0", "#d55e00", "#009e73", "#a06a00", "#cc79a7", "#56b4e9"]
const BANDS = [
  {top: "under", bottom: "4 min", span: "under 4 minutes"},
  {top: "4 to 34", bottom: "min", span: "4 to 34 minutes"},
  {top: "34 min", bottom: "to 5 h", span: "34 minutes to 5 hours"},
  {top: "5 to 36", bottom: "hours", span: "5 to 36 hours"},
  {top: "over", bottom: "36 hours", span: "over 36 hours"}
]

const masterSpec = (won, n) => ({
  kind: "master",
  bands: BANDS,
  won,
  n,
  cells: won.map((v, i) => (v === null ? null : {w: 1, d: 0, l: 1, n: n[i]}))
})

const master = (spec) => masterOption({spec, colour: CAT, ink: INK, text: INK})

// ⚠ A LINEAR COORDINATE FAKE, NOT THE CONSTANT ONE THE MATRIX USES. The matrix
// only needed widths, so one point was enough. Here the whole reading is VERTICAL
// POSITION, so the fake has to map a percentage to a pixel the way an axis does:
// 0% at y=240, 100% at y=40, one band 100px wide and 200px tall.
const coordFake = (i, won, n) => ({
  coord: ([x, y]) => [40 + x * 100, 240 - y * 2],
  size: () => [100, 200],
  value: (k) => [i, won, n][k]
})

const geom = (spec, i) => {
  const drawn = master(spec)
    .series[0].renderItem({}, coordFake(i, spec.won[i], spec.n[i]))
  const kids = drawn.children
  const bars = kids.filter((k) => k.type === "rect")
  const [body, rule] = bars

  return {
    kids: kids.length,
    rects: bars.length,
    bodyH: body && body.shape.height,
    ruleY: rule && rule.shape.y,
    ruleH: rule && rule.shape.height,
    ruleW: rule && rule.shape.width,
    ruleOpacity: rule && rule.style.opacity
  }
}

const spread = (spec) => {
  const ys = spec.won
    .map((v, i) => (v === null ? null : geom(spec, i).ruleY))
    .filter((y) => y !== null)
  return Math.max(...ys) - Math.min(...ys)
}

// ⚠⚠ THE DISCRIMINATOR, AND THE ONLY CHECK ON THIS PAGE THAT TESTS A CLAIM
// ABOUT MEANING. The two shapes the panel exists to separate must separate by
// more than a third of the canvas.
const flat = masterSpec([62, 62, 62, 62, 62], [18, 12, 9, 8, 7])
const falling = masterSpec([90, 72, 54, 36, 18], [18, 12, 9, 8, 7])
check("a level profile draws level", spread(flat) < 0.5, `${spread(flat)}px apart`)
check("a treadmill falls away by more than a hundred pixels",
  spread(falling) > 100, `${spread(falling)}px`)

const flatOpt = master(flat)
const fsvg = render(flatOpt)
const fallSvg = render(master(falling))

// An axis fitted to the data would turn 88-to-94 into a cliff, which is the
// treadmill's own picture drawn from six points of noise.
check("the axis is the real ceiling, not the data range",
  flatOpt.yAxis.min === 0 && flatOpt.yAxis.max === 100, `${flatOpt.yAxis.min}..${flatOpt.yAxis.max}`)
check("a higher rate is drawn higher, so the chart is not upside down",
  geom(falling, 0).ruleY < geom(falling, 4).ruleY,
  `90% at ${geom(falling, 0).ruleY}, 18% at ${geom(falling, 4).ruleY}`)

// ⚠ A RULE SPANS ITS BAND, because a band is an INTERVAL of ages and a point
// mark would claim a measurement at one age that nothing took.
check("a rule spans its whole band, less the surface gap",
  geom(flat, 0).ruleW === 96, `${geom(flat, 0).ruleW}px of 100`)

// ⚠⚠ A MEASURED ZERO IS A RULE ON THE BASELINE AT FULL STRENGTH. "We flew it and
// lost every one" and "we drew nothing from this age" are the two states this
// whole panel keeps having to tell apart, and a zero-height column is what they
// look like when it fails.
const zeroed = masterSpec([0, 58, 41, 30, 19], [8, 12, 9, 8, 7])
const zero = geom(zeroed, 0)
check("a measured zero still draws a rule, sitting on the baseline",
  zero.rects === 2 && zero.ruleH >= 3 && zero.ruleY <= 240 - 3,
  `${zero.rects} rects, ${zero.ruleH}px tall, at y=${zero.ruleY}`)

// ⚠⚠⚠ AND A GAP DRAWS NOTHING AT ALL. Not a zero, not a bridge to its
// neighbours.
const gapped = masterSpec([62, 58, null, 41, 19], [18, 12, null, 8, 4])
const painted = gapped.won.reduce((n, _v, i) => n + geom(gapped, i).rects, 0)
check("an age nothing was drawn from renders nothing", geom(gapped, 2).kids === 0)
check("every measured band draws exactly two marks and no band draws three",
  painted === 2 * 4, `${painted} rects for 4 measured bands`)

// ⚠ ALL FIVE BANDS, WHATEVER THE DATA HOLDS. An empty right-hand column is the
// finding "we hold nothing that old"; a column fitted away says nothing.
const lone = masterSpec([62, null, null, null, null], [18, null, null, null, null])
check("all five age bands are drawn even when one is measured",
  master(lone).xAxis.data.length === 5, `${master(lone).xAxis.data.length} bands`)
check("an unmeasured band prints no denominator",
  master(lone).xAxis.data[1].endsWith("·") && master(lone).xAxis.data[0].endsWith("n=18"))

// Opacity is confidence, and it is not the only channel: the denominator is
// printed under every tick because a faded mark is not a number.
const thinBand = masterSpec([50, 50, 50, 50, 50], [2, 12, 9, 8, 7])
check("a band decided by two fights is drawn faintly",
  geom(thinBand, 0).ruleOpacity === 0.42, `${geom(thinBand, 0).ruleOpacity}`)
check("a band decided by eight is drawn at full strength",
  geom(thinBand, 3).ruleOpacity === 1, `${geom(thinBand, 3).ruleOpacity}`)
check("a thin band is fainter than a sure one",
  geom(thinBand, 0).ruleOpacity < geom(thinBand, 3).ruleOpacity)

// ⚠⚠ TWO MARKS PER BAND, AND A THIRD WOULD BE A CONSTANT. A faint hairline for
// "won or drew" was drawn here until 2026-08-09 and was measured out: draws are
// zero in every published cell but one, across both exams and all five islands,
// so it sat exactly on top of the rule it was meant to differ from. A visual
// channel is spent only on something that varies, and this exhibit has now shed
// three encodings of constants in one day.
//
// The count is not lost. It rides in `cells` for the tooltip and the table.
const anyBand = masterSpec([50, 50, 50, 50, 50], [6, 6, 6, 6, 6])
check("a band draws a body and a rule, and nothing for the draws",
  geom(anyBand, 0).rects === 2, `${geom(anyBand, 0).rects} rects`)
check("the draws are still carried in the data for the tooltip",
  anyBand.cells[0].d === 0 && "d" in anyBand.cells[0])

// ⚠ A THIN OR LONE BAND DOES NOT GET TO RULE THE CHART. With one band measured
// there is nothing to be level WITH, so the reading is withdrawn rather than
// drawn against itself.
check("the newest sure band rules the chart",
  flatOpt.series[0].markLine.data[0].yAxis === 62)
check("a newest band decided by two fights rules nothing",
  master(thinBand).series[0].markLine === undefined)
check("one measured band rules nothing",
  master(lone).series[0].markLine === undefined)

// ⚠⚠ THE SEAT COLOURS ARE THE GOOD-FAITH MISTAKE HERE. Our drone genuinely sits
// in the attacker's seat and the invader defends, so somebody will reach for
// them. This is a RATE, not two sides of one mark, and red on a page that
// teaches "red is what is coming at us" would say the archipelago is the threat.
check("the master profile never uses a seat colour",
  !paints(fsvg, SIDES.attacker) && !paints(fsvg, SIDES.defender) && !paints(fsvg, SIDES.draw))
// One entity, one hue. There is nothing here to tell apart, so a categorical
// cycle would be five colours encoding nothing.
check("one hue only, never a categorical cycle",
  rects(fsvg, CAT[1]) === 0 && rects(fsvg, CAT[2]) === 0,
  `${rects(fsvg, CAT[1])} in slot 2, ${rects(fsvg, CAT[2])} in slot 3`)
check("the profile is painted in the first categorical hue", rects(fsvg, CAT[0]) > 0)
check("rules rendered without NaN", !/NaN/.test(fsvg) && !/NaN/.test(fallSvg))
check("no mark is drawn at negative width", !/width="-/.test(fsvg))

// The deploy-skew contract: a fleet on an older build draws no frame at all.
check("a fleet that has sat nothing draws nothing",
  master(masterSpec([null, null, null, null, null], [null, null, null, null, null])) === null)
check("no bands at all draws nothing",
  masterOption({spec: {kind: "master", bands: [], won: [], ceiling: [], n: []}, colour: CAT, ink: INK, text: INK}) === null)

console.log("tokens")
// ⚠ THE HOOK USED TO READ ITS TOKENS THROUGH FOUR SEPARATE CLOSURES, two of
// which were deleted by an edit aimed at a third. esbuild leaves an undefined
// global alone, the browser threw a ReferenceError at call time, and the hook's
// own guard turned that into a blank box on every chart. Now one function, and
// the checker exercises it.
const stylesheet = {
  "--color-base-content": "#e7e5e4",
  "--chart-cat-1": "#2a6fb0", "--chart-cat-2": "#d55e00", "--chart-cat-3": "#009e73",
  "--chart-cat-4": "#a06a00", "--chart-cat-5": "#cc79a7", "--chart-cat-6": "#56b4e9",
  "--chart-seq-1": "#8ab8dc", "--chart-seq-5": "#0f3d61",
  "--side-attacker": "#e2556e", "--side-defender": "#4c8dff", "--side-draw": "#8a8a86"
}
const t = tokens((n) => stylesheet[n])

check("every categorical hue is read", t.palette.length === 6, `${t.palette.length}`)
check("both ends of the sequential ramp are read", t.ramp.length === 2 && t.ramp[0] !== t.ramp[1])
check("all three sides are read",
  t.sides.attacker === SIDES.attacker && t.sides.defender === SIDES.defender && t.sides.draw === SIDES.draw)
check("ink is read", t.ink === INK)

// A stylesheet that fails to load must degrade to the picture that shipped, not
// to an exception or to black on black.
const bare = tokens(() => "")
check("missing tokens fall back rather than throwing",
  bare.sides.attacker === SIDES.attacker && bare.ink === "#666" && bare.ramp.length === 2)
check("a missing categorical ramp is empty, not a list of blanks", bare.palette.length === 0)

console.log("skew")
check("an unknown spec returns nothing", barsOption({spec: {kind: "something-new"}, colour: [], text: INK, fill: SIDES}) === null)
check("a matrix without cells returns nothing", matrixOption({spec: {kind: "matrix"}, fill: SIDES, text: INK, height: H}) === null)

// ⚠ EVERYTHING ABOVE RENDERS A BUILDER THE BROWSER MIGHT NEVER CALL, AND ONE OF
// THEM DID NOT CALL IT FOR WEEKS. `ratesOption` was exported here, checked here,
// and missing from the hook's import line and its dispatch chain, so
// `dronex_raids_live.ex` published `kind: "rates"`, fell through to `barsOption`,
// and shipped stacked bars with a blank legend — while the check above asserted
// "grouped, not stacked" against a function that never ran in a browser. Every
// check was green and the picture was wrong.
//
// So this reads the two files as TEXT. A builder must be named at least twice in
// the hook: once to import it and once to call it.
console.log("dispatch")
const source = (f) => readFileSync(new URL(f, import.meta.url), "utf8")
// ⚠ COMMENTS STRIPPED, AND WITHOUT THIS THE CHECK BELOW DOES NOT BITE. It
// counts a builder's name anywhere in the file, so a comment naming
// `ratesOption` in prose scored 2 on its own. Proven by deleting the
// `rates:` line from the dispatch table, which is the exact bug that
// shipped stacked bars on /dronex/raids for weeks: all 43 checks stayed
// green.
const hookSource = source("./dronex_chart_hook.js").replace(/^\s*\/\/.*$/gm, "")
const builders = [...source("./dronex_charts.js").matchAll(/export function (\w+Option)\b/g)].map((m) => m[1])

check("every builder in the file is exercised here", builders.length === 7, `${builders.length} builders`)
for (const name of builders) {
  const uses = (hookSource.match(new RegExp(name, "g")) || []).length
  check(`the hook imports and calls ${name}`, uses >= 2, `named ${uses} time(s)`)
}

console.log(failures === 0 ? "\nall chart checks passed" : `\n${failures} chart check(s) FAILED`)
process.exit(failures === 0 ? 0 : 1)
