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
