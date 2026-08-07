// Chart options for /dronex, as pure functions.
//
// ⚠ THESE LIVE HERE SO A MACHINE CAN LOOK AT THE PICTURE. Twice in one afternoon
// this page shipped a chart that was arithmetically correct and visually wrong: a
// cell tint at 48% over a dark surface that could not be seen at all, and an
// in-flight marker whose radius was computed from percentages and pixels at once,
// drawn four rows tall. Both passed their tests. Both were caught by a human
// sending a screenshot, which is not a process.
//
// ECharts renders SVG server-side under Node, so an option built by a pure
// function can be rendered and MEASURED without a browser. `charts_check.mjs`
// does exactly that. Nothing in this file may touch the DOM, `window` or CSS
// variables: the hook resolves those and passes them in.

export function barsOption({spec, colour, text, fill}) {
  if (!Array.isArray(spec.series)) return null

  return {
      color: colour,
      textStyle: {color: text, fontFamily: "inherit"},
      grid: {left: 44, right: 12, top: 28, bottom: 34},
      tooltip: {trigger: "axis", axisPointer: {type: "shadow"}},
      legend: {show: spec.series.length > 1, top: 0, textStyle: {color: text}},
      xAxis: {
        type: "category",
        name: spec.x_name,
        nameLocation: "middle",
        nameGap: 24,
        data: spec.categories,
        axisLabel: {color: text, opacity: 0.6},
        axisLine: {lineStyle: {opacity: 0.2}}
      },
      yAxis: {
        type: "value",
        name: spec.y_name,
        minInterval: 1,
        axisLabel: {color: text, opacity: 0.6},
        splitLine: {lineStyle: {opacity: 0.12}}
      },
      series: spec.series.map((s, i) => ({
        name: s.name,
        type: "bar",
        stack: "all",
        emphasis: {focus: "series"},
        // ⚠ A ROLE OVERRIDES THE PALETTE. A raider is red and an island is blue
        // everywhere on this page; a series that names a role takes the
        // convention, and anything else falls back to its position.
        itemStyle: {color: (s.role && fill[s.role]) || colour[i % colour.length]},
        data: s.data
      }))
  }
}

export function matrixOption({spec, fill, text, height}) {
  if (!Array.isArray(spec.cells) || !spec.rows) return null

  const px = height || 288
  const left = 20, top = 14
  const w = (100 - left) / spec.cols.length
  const h = (100 - top) / spec.rows.length

  const at = (r, c) => [left + (c + 0.5) * w, top + (r + 0.5) * h]

  // ⚠ ONE SIZE FOR EVERY CELL. Area used to carry the raid count, and
  // it cost more than it bought: the eye compares PROPORTIONS across a
  // grid, and it cannot do that when every disc is a different size. It
  // also made the smallest routes almost invisible. The count is a
  // number in the middle of the ring now, which is legible at a glance
  // and needs no judging of areas.
  //
  // Sized off the real cell height in pixels, not off a percentage, so
  // a ring can never be drawn larger than the row it lives in.
  const rowPx = (px * (100 - top) / 100) / spec.rows.length
  const R = Math.max(8, Math.min(18, rowPx * 0.34))
  const inner = R * 0.55

  const series = spec.cells.filter((c) => c.n > 0).map((cell) => {
    const [cx, cy] = at(cell.r, cell.c)
    return {
      type: "pie",
      name: cell.of,
      center: [`${cx}%`, `${cy}%`],
      radius: [inner, R],
      label: {show: false},
      labelLine: {show: false},
      emphasis: {scale: true, scaleSize: 2},
      data: [
        {value: cell.a, name: "raider won", itemStyle: {color: fill.attacker}},
        {value: cell.x, name: "drawn", itemStyle: {color: fill.draw}},
        {value: cell.d, name: "island held", itemStyle: {color: fill.defender}}
      ].filter((s) => s.value > 0)
    }
  })

  // How many raids, as a number, in the hole of the ring.
  const counts = spec.cells.filter((c) => c.n > 0).map((c) => {
    const [cx, cy] = at(c.r, c.c)
    return {
      type: "text",
      left: `${cx}%`,
      top: `${cy}%`,
      style: {
        text: String(c.n), fill: text, opacity: 0.75,
        font: "10px monospace", align: "center", verticalAlign: "middle"
      }
    }
  })

  // ⚠⚠ A RAID STILL OUT, AND THE FIRST VERSION OF THIS WAS ENORMOUS.
  // It set a 6px radius and then scaled it by a number computed from
  // PERCENTAGES, so a marker meant to sit inside one cell was drawn
  // across four rows. Pixels here, no scale transform, and it sits just
  // outside the ring so it reads as an annotation on the cell rather
  // than as a shape of its own.
  const flying = spec.cells.filter((c) => c.f > 0).map((c) => {
    const [cx, cy] = at(c.r, c.c)
    return {
      type: "circle",
      left: `${cx}%`,
      top: `${cy}%`,
      shape: {cx: 0, cy: 0, r: R + 3},
      style: {fill: "none", stroke: fill.draw, lineDash: [3, 3], lineWidth: 1},
      z: 10
    }
  })

  const labels = [
    ...spec.rows.map((name, r) => ({
      type: "text",
      left: `${left - 1.5}%`,
      top: `${at(r, 0)[1]}%`,
      style: {text: name, fill: text, opacity: 0.6, font: "11px monospace", align: "right", verticalAlign: "middle"}
    })),
    ...spec.cols.map((name, c) => ({
      type: "text",
      left: `${at(0, c)[0]}%`,
      top: `${top - 8}%`,
      style: {text: name, fill: text, opacity: 0.5, font: "11px monospace", align: "center"}
    }))
  ]

  return {
    tooltip: {
      trigger: "item",
      formatter: (p) => {
        const c = p.data && p.data.tip ? p.data.tip : (p.seriesModel || {})
        const t = spec.cells.find((x) => x.of === p.seriesName) || {}
        const out = t.f > 0 ? `, ${t.f} still out` : ""
        return `${p.seriesName}: ${t.n} raids, ${t.a} won, ${t.d} held${out}`
      }
    },
    graphic: [...labels, ...counts, ...flying],
    series
  }

}

// ⚠ THE D.15 INSTRUMENT. One column per sample, one row per rung, fill is the
// win rate on that drill. A vertical stripe is every rung moving together, which
// is a changed sitter or a changed harness; erosion from the top is a skill
// genuinely lost; a recovery on different rungs from the ones that fell is a
// different animal wearing the same score. None of that is visible in the single
// percentage the leaderboard ranks on.
//
// ⚠⚠ ONE HUE, LIGHT TO DARK, because a win rate is a MAGNITUDE. Not the side
// colours: a drill has no raider and no island, and lending it red would say it
// did. Not a rainbow: `visualMap` interpolates between the two ends given, so
// two steps of one ramp is the whole scale.
export function examOption({spec, ramp, text}) {
  if (!spec || !Array.isArray(spec.cells) || spec.cells.length === 0) return null

  return {
    tooltip: {
      trigger: "item",
      formatter: (p) => `drill ${p.data[1] + 1}: ${p.data[2]}%`
    },
    grid: {left: 56, right: 16, top: 10, bottom: 26},
    xAxis: {type: "category", data: spec.columns.map((_, i) => i), show: false},
    yAxis: {
      type: "category",
      data: Array.from({length: spec.rungs}, (_, i) => `drill ${i + 1}`),
      axisLabel: {color: text, opacity: 0.6, fontSize: 10},
      axisLine: {show: false},
      axisTick: {show: false}
    },
    visualMap: {
      min: 0,
      max: 100,
      calculable: false,
      orient: "horizontal",
      right: 16,
      bottom: 0,
      itemWidth: 10,
      itemHeight: 60,
      textStyle: {color: text, opacity: 0.5, fontSize: 10},
      inRange: {color: ramp}
    },
    series: [
      {
        type: "heatmap",
        data: spec.cells.map((c) => [c.x, c.y, c.rate]),
        progressive: 0,
        itemStyle: {borderWidth: 0}
      }
    ]
  }
}

// ⚠ THE ABLATION TRIO, COLLECTED FOR HOURS AND NEVER DRAWN. `air`, `ground` and
// `all` are the change in the raider's score when a channel is silenced. The
// board's own comment says a trajectory is the only thing that resolves them:
// "sampled over hours, a channel that matters drifts off zero and noise does
// not". These three series existed for a chart that had never been built.
//
// ⚠⚠ CATEGORICAL HUES, NEVER `--side-*`. A silenced channel has no raider and no
// island, and this sits on a page that teaches red means raider.
//
// ⚠⚠⚠ AND ZERO IS DRAWN, EXPLICITLY. The whole reading is whether a line sits
// off zero and stays there. A chart of a signed quantity with no zero line asks
// the reader to guess where it is.
export function ablationOption({spec, colour, text}) {
  if (!spec || !Array.isArray(spec.series) || spec.series.length === 0) return null

  const reach = Math.max(30, ...spec.series.flatMap((s) => s.data.map((v) => Math.abs(v || 0))))

  return {
    color: colour,
    textStyle: {color: text, fontFamily: "inherit"},
    grid: {left: 40, right: 12, top: 24, bottom: 24},
    tooltip: {trigger: "axis"},
    legend: {show: true, top: 0, textStyle: {color: text}},
    xAxis: {type: "category", data: spec.at.map((_, i) => i), show: false},
    yAxis: {
      type: "value",
      min: -reach,
      max: reach,
      axisLabel: {color: text, opacity: 0.6, fontSize: 10},
      splitLine: {lineStyle: {opacity: 0.1}}
    },
    series: spec.series.map((s) => ({
      name: s.name,
      type: "line",
      // ⚠ STEPS, NOT SLOPES. The wire republishes ONE exercise until the next is
      // run, so the samples between are the same measurement repeated. A sloped
      // line between two identical readings draws a trend that was never
      // measured.
      step: "end",
      symbol: "none",
      lineStyle: {width: 2},
      data: s.data,
      markLine: {
        silent: true,
        symbol: "none",
        lineStyle: {color: text, opacity: 0.35, type: "solid", width: 1},
        data: [{yAxis: 0}],
        label: {show: false}
      }
    }))
  }
}
