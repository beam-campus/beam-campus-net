// The DroneX chart hook: the part of a chart only a browser can do.
//
// ⚠ A NORMAL HOOK, NOT A COLOCATED ONE, AND THAT IS WHAT LETS /dronex BE FOUR
// PAGES. A colocated hook is scoped to the module that declares it, so the six
// charts spread across four LiveViews would need four copies of this file
// inlined into four .ex files. It lived inside `how_long_fights_last`'s markup
// when one module drew everything.
//
// Registered by name in app.js and used as phx-hook="DronexChart".

// A CHART, DRAWN BY A CHARTING LIBRARY. Everything on this page was hand
// rolled SVG and divs before this: no axes, no ticks, no tooltips, no
// legend, and a bar chart that was a row of coloured rectangles with the
// scale printed underneath as two numbers.
//
// ⚠ THE COLOURS COME FROM THE STYLESHEET, NEVER FROM THE SPEC. The server
// sends shape and data; the browser reads --chart-cat-* off :root so a
// theme switch repaints without a round trip, and so there is exactly one
// place the brand palette lives.
//
// ⚠⚠ AND phx-update="ignore" IS LOAD-BEARING. ECharts owns the DOM inside
// this element; letting LiveView patch it would fight the renderer. New
// data arrives through the data-spec attribute, which `updated()` reads.
// ⚠ RELATIVE PATHS NOW, AND THE `@' ALIAS BEFORE. While this was a COLOCATED
// hook it was extracted to `_build/dev/phoenix-colocated/...' before esbuild
// saw it, so "../vendor" resolved against that directory instead of assets/ and
// the `--alias:@=.' escape hatch was the way in. This file actually lives in
// assets/js now, so the ordinary path is the truthful one.
import * as echarts from "../vendor/echarts.esm.js"
import {barsOption, matrixOption, examOption, ablationOption, examProfileOption, tokens} from "./dronex_charts.js"
// Six, in the order the stylesheet declares them, because that order is
// what the colour-blindness check was run against. Taking them in any
// other sequence puts pink beside green and fails a check that passed.
// ⚠ ONE READER, NOT FOUR CLOSURES. Four of these lived here, two were
// deleted by an edit aimed at a third, esbuild left them as undefined
// globals, and every chart went blank while the server logs stayed clean.
const read = () =>
  tokens((name) => getComputedStyle(document.documentElement).getPropertyValue(name))
export default {
  // ⚠ NOTHING IN HERE MAY TAKE THE PAGE WITH IT. A hook callback throwing
  // during `applyJoinPatch' aborts the join, and the visitor gets
  // "Something went wrong, attempting to reconnect" instead of a page.
  // That happened on 2026-08-07: a browser holding the PREVIOUS bundle
  // live-navigated into markup carrying a spec shape that bundle had
  // never heard of, read `spec.series.length' off a matrix, and threw.
  //
  // Deploy skew cannot be fixed from the new side, because the old code
  // is what runs. What can be fixed is the blast radius: a chart that
  // cannot draw is an empty box, never a dead page.
  safely(what) {
    try {
      what()
    } catch (e) {
      console.error("[dronex] chart not drawn:", e)
    }
  },
  mounted() {
    this.chart = echarts.init(this.el, null, {renderer: "svg"})
    this.safely(() => this.draw())
    this.onResize = () => this.safely(() => this.chart.resize())
    window.addEventListener("resize", this.onResize)
    // A theme toggle changes the custom properties under us, and the
    // chart has already resolved them, so it has to be told.
    this.theme = new MutationObserver(() => this.safely(() => this.draw()))
    this.theme.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"]
    })
  },
  updated() { this.safely(() => this.draw()) },
  destroyed() {
    window.removeEventListener("resize", this.onResize)
    this.theme?.disconnect()
    this.chart?.dispose()
  },
  // ⚠ THE OPTION IS BUILT BY A PURE FUNCTION IN `dronex_charts.js', so a
  // checker can render it under Node and MEASURE the result. This hook
  // now only does what only a browser can: resolve the CSS custom
  // properties and hand over the element's real height.
  draw() {
    const spec = JSON.parse(this.el.dataset.spec)
    const t = read()
    const text = t.ink
    // The panel behind the chart, so a mark can be separated from its
    // neighbour by a gap in the surface rather than by a line of its own.
    const surface = getComputedStyle(this.el.parentElement).backgroundColor
    const option =
      spec.kind === "matrix"
        ? matrixOption({spec, fill: t.sides, text, surface, height: this.el.clientHeight || 288})
        : spec.kind === "exam_profile"
          ? examProfileOption({spec, colour: t.palette, text})
        : spec.kind === "exam"
          ? examOption({spec, ramp: t.ramp, text, surface})
          : spec.kind === "ablation"
            ? ablationOption({spec, colour: t.palette, text})
            : barsOption({spec, colour: t.palette, text, fill: t.sides, surface})
    if (!option) {
      console.warn("[dronex] chart spec not understood, not drawing:", spec.kind)
      return
    }
    this.chart.setOption(option, {notMerge: true})
  }
}

