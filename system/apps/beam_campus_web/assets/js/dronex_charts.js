// Chart options for /dronex, as pure functions.
//
// House marks, applied by every builder below:
//   - data-ends rounded 4px and anchored to the baseline, never both ends
//   - a 1px gap in the panel colour between stacked segments and pie slices
//   - no axis ticks, grid lines at 12% and axis lines at 20%
//   - a staggered entrance, because everything here arrives at once on mount
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

export function barsOption({spec, colour, text, fill, surface}) {
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
        axisTick: {show: false},
        axisLine: {lineStyle: {opacity: 0.2}}
      },
      yAxis: {
        type: "value",
        name: spec.y_name,
        minInterval: 1,
        axisLabel: {color: text, opacity: 0.6},
        axisLine: {show: false},
        axisTick: {show: false},
        splitLine: {lineStyle: {opacity: 0.12}}
      },
      animationDuration: 520,
      animationEasing: "cubicOut",
      animationDelay: (i) => i * 40,
      series: spec.series.map((s, i) => ({
        name: s.name,
        type: "bar",
        stack: "all",
        barMaxWidth: 34,
        emphasis: {focus: "series"},
        // ⚠ A ROLE OVERRIDES THE PALETTE. A raider is red and an island is blue
        // everywhere on this page; a series that names a role takes the
        // convention, and anything else falls back to its position.
        itemStyle: {
          color: (s.role && fill[s.role]) || colour[i % colour.length],
          // ⚠ THE TOP OF THE STACK ONLY. Rounding both ends of a segment would
          // detach it from the baseline and from the segment beneath it.
          borderRadius: i === spec.series.length - 1 ? [4, 4, 0, 0] : 0,
          borderColor: surface,
          borderWidth: 1
        },
        data: s.data
      }))
  }
}

export function matrixOption({spec, fill, text, height, surface}) {
  if (!Array.isArray(spec.cells) || !spec.rows) return null

  // ⚠ EACH CELL IS SPLIT, NOT TINTED, AND THE TINT WAS THE THIRD WRONG ANSWER.
  // Pies were first: a slice asks the eye to judge an ANGLE, the least accurate
  // comparison there is. A diverging tint was second, and the comment defending
  // it claimed comparing two colours is "the most accurate" judgement. That is
  // backwards. Position and length are the accurate channels; colour is near the
  // bottom for magnitude. A 60/40 route and a 55/45 route are two tints nobody
  // can tell apart, and a route at 50 lands on the same grey as a route with too
  // few raids to say.
  //
  // So the cell is a stacked proportion: blue for the share the island held, red
  // for the share the raider took, side by side. The reader compares two LENGTHS
  // against a shared cell width, which is the judgement they are actually good
  // at, and the two hues stay pure instead of being interpolated through grey.
  //
  // ⚠⚠ A 2px SURFACE GAP BETWEEN THE SEGMENTS, NEVER A BORDER AROUND THEM. A
  // stroke drawn to separate marks adds a line the data does not contain; a gap
  // in the surface colour separates them with nothing.
  //
  // ⚠⚠⚠ AND THE COUNT IS CENTRED ON THE WHOLE CELL, NOT INSIDE A SEGMENT. A
  // lopsided route has one segment a few pixels wide, and a label placed in it
  // would be clipped exactly where the split is most worth reading.
  const decided = (c) => c.a + c.d
  const share = (c) => (decided(c) === 0 ? 0.5 : c.a / decided(c))

  // Below this a cell states its numbers and does not shout a direction: one
  // raid won is 100%, and at full strength it would be the loudest thing here.
  const SURE = 3
  const GAP = 2

  return {
    animationDuration: 420,
    animationEasing: "cubicOut",
    grid: {left: 96, right: 16, top: 28, bottom: 8},
    tooltip: {
      trigger: "item",
      formatter: (p) => {
        const c = spec.cells[p.dataIndex]
        const out = c.f > 0 ? `, ${c.f} still out` : ""
        return `${c.of}: ${c.n} raids, ${c.a} won, ${c.d} held${out}`
      }
    },
    xAxis: {
      type: "category",
      position: "top",
      data: spec.cols,
      axisLabel: {color: text, opacity: 0.55, fontSize: 10},
      axisLine: {show: false},
      axisTick: {show: false},
      splitArea: {show: false}
    },
    yAxis: {
      type: "category",
      data: spec.rows,
      // ⚠ INVERTED, BECAUSE A CATEGORY AXIS COUNTS UP FROM THE BOTTOM. Without
      // this the rows run msi00 to beam00 while the columns run beam00 to msi00,
      // so the blank self-raid cells fall on the ANTI-diagonal and row `i' is not
      // column `i'. Every reading of the grid is then transposed by eye.
      inverse: true,
      axisLabel: {color: text, opacity: 0.55, fontSize: 10},
      axisLine: {show: false},
      axisTick: {show: false},
      splitArea: {show: false}
    },
    series: [
      {
        type: "custom",
        data: spec.cells.map((c) => [c.c, c.r, share(c), c.n, decided(c)]),
        encode: {tooltip: [0, 1]},
        renderItem: (params, api) => {
          const at = api.coord([api.value(0), api.value(1)])
          const size = api.size([1, 1])
          const w = size[0] - GAP * 2
          const h = size[1] - GAP * 2
          const x = at[0] - w / 2
          const y = at[1] - h / 2

          const taken = api.value(2)
          const count = api.value(3)
          const sure = api.value(4) >= SURE
          const opacity = sure ? 1 : 0.42

          // The island's share on the left, the raider's on the right, with the
          // gap between them coming out of the middle so the pair still spans
          // the cell.
          const held = Math.max(0, (w - GAP) * (1 - taken))
          const won = Math.max(0, w - GAP - held)

          return {
            type: "group",
            children: [
              {
                type: "rect",
                shape: {x, y, width: held, height: h, r: [3, 0, 0, 3]},
                style: {fill: fill.defender, opacity}
              },
              {
                type: "rect",
                shape: {x: x + held + GAP, y, width: won, height: h, r: [0, 3, 3, 0]},
                style: {fill: fill.attacker, opacity}
              },
              {
                type: "text",
                style: {
                  x: at[0],
                  y: at[1],
                  text: String(count),
                  textAlign: "center",
                  textVerticalAlign: "middle",
                  fill: text,
                  fontFamily: "monospace",
                  fontSize: 11,
                  // Full strength even on a faded cell: the fill carries the
                  // confidence and the number must stay readable regardless.
                  opacity: 1
                }
              }
            ]
          }
        }
      }
    ]
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
export function examOption({spec, ramp, text, surface}) {
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
        itemStyle: {borderRadius: 1, borderColor: surface, borderWidth: 0.5}
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

// ⚠ THE EXAM AS A PROFILE, WHICH IS THE ONLY WAY IT CAN BE READ. The drills are
// NAMED and ORDERED by difficulty, so a grouped bar keeps that order on the axis
// and puts every island against every drill. Two islands on the same score can
// have opposite shapes, and one number cannot say so.
//
// ⚠⚠ CATEGORICAL HUES, ONE PER ISLAND. An island is an identity, not a side and
// not a magnitude, so this takes the categorical ramp and never `--side-*`.
export function examProfileOption({spec, colour, text}) {
  if (!spec || !Array.isArray(spec.series) || spec.series.length === 0) return null
  if (!Array.isArray(spec.drills) || spec.drills.length === 0) return null

  return {
    color: colour,
    textStyle: {color: text, fontFamily: "inherit"},
    grid: {left: 40, right: 12, top: 30, bottom: 30},
    tooltip: {trigger: "axis", axisPointer: {type: "shadow"}},
    legend: {show: true, top: 0, textStyle: {color: text}},
    xAxis: {
      type: "category",
      data: spec.drills,
      axisLabel: {color: text, opacity: 0.7, fontSize: 10},
      axisTick: {show: false},
      axisLine: {lineStyle: {opacity: 0.2}}
    },
    yAxis: {
      type: "value",
      // ⚠ ALWAYS 0 TO 100, NEVER FITTED TO THE DATA. A win rate has a real
      // ceiling, and an axis that rescales to the range makes a fleet at 90–97%
      // look as spread out as one at 3–97%.
      min: 0,
      max: 100,
      axisLabel: {color: text, opacity: 0.6, formatter: "{value}%"},
      axisLine: {show: false},
      axisTick: {show: false},
      splitLine: {lineStyle: {opacity: 0.12}}
    },
    animationDuration: 520,
    animationEasing: "cubicOut",
    animationDelay: (i) => i * 25,
    series: spec.series.map((s) => ({
      name: s.island,
      type: "bar",
      barMaxWidth: 14,
      emphasis: {focus: "series"},
      itemStyle: {borderRadius: [3, 3, 0, 0]},
      data: s.rates
    }))
  }
}

// ⚠ THE MASTER TOURNAMENT: ONE POOLED PROFILE ACROSS FIVE FIXED AGE BANDS, DRAWN
// AS LEVEL RULES. The whole panel exists to make ONE distinction unmissable:
// a level profile is genuine progress (the archipelago still beats what beat it
// long ago), and a profile falling away to the right is a TREADMILL (a population
// cycling, beating what it fights now and losing to what it used to beat, while
// every local number rises).
//
// Level rules are the only form where "flat" is a single alignment judgement
// rather than a trend inferred across gaps. Position on a common scale is
// pre-attentive; a slope between bands that are factors of two apart in age is a
// claim of continuity nobody measured.
//
// ⚠⚠ NEWEST LEFT, ANCIENT RIGHT, so a treadmill falls away to the right in
// reading order. Reversed, a treadmill would draw as a RISING line.
//
// ⚠⚠⚠ ONE HUE, ONE ENTITY, AND NEVER `--side-*`. Our drone genuinely sits in the
// attacker's seat and the invader defends, so reaching for the seat colours is
// the good-faith mistake here. This is a rate, not two sides of one mark, and
// painting the archipelago red on a page that teaches "red is what is coming at
// us" inverts the site's own convention. The checker refuses all three.
//
// `type: "custom"` because renderItem is the only shape whose pixel geometry can
// be read back by a pure function — which is how the checker catches the bug
// class every colour assertion misses.
// `ink` is the hue of a MARK the data did not put there (the guide rule); `text`
// is the hue of a LABEL. They resolve to the same token today and are named
// apart because only one of them is allowed to draw a line across the plot.
export function masterOption({spec, colour, ink, text}) {
  if (!spec || !Array.isArray(spec.bands) || spec.bands.length === 0) return null
  if (!Array.isArray(spec.won)) return null

  const drawn = (v) => v !== null && v !== undefined
  const measured = spec.won.reduce((n, v, i) => (drawn(v) ? n.concat(i) : n), [])
  if (measured.length === 0) return null

  const hue = (colour && colour[0]) || ink
  const first = measured[0]
  const last = measured[measured.length - 1]

  // ⚠ THE GUIDE RULE IS DERIVED HERE AND NOWHERE ELSE. A thin band does not get
  // to rule the chart, and with one band measured there is nothing to be level
  // WITH, so the reading is withdrawn rather than drawn against itself.
  const SURE = 6
  const guide = measured.length >= 2 && spec.n[first] >= SURE ? spec.won[first] : null

  const GAP = 2
  const RULE = 3

  return {
    textStyle: {color: text, fontFamily: "inherit"},
    grid: {left: 46, right: 16, top: 24, bottom: 62},
    tooltip: {
      trigger: "item",
      formatter: (p) => {
        const i = p.dataIndex
        const c = spec.cells[i]
        if (!c) return `${spec.bands[i].span}: nothing drawn from this band`
        return (
          `${spec.bands[i].span} · ${c.n} fights: ` +
          `${c.w} won, ${c.d} drawn, ${c.l} lost · ${spec.won[i]}% won`
        )
      }
    },
    xAxis: {
      type: "category",
      // ⚠ ALL FIVE BANDS, ALWAYS, whatever the data holds. The bands are
      // contiguous and exhaustive by construction, so an empty right-hand column
      // says "we hold nothing that old" — which is a finding. A column fitted
      // away says nothing at all.
      data: spec.bands.map((b, i) => [b.top, b.bottom, tick(spec.n[i])].join("\n")),
      name: "how long ago it attacked us · island uptime",
      nameLocation: "middle",
      nameGap: 46,
      axisLabel: {color: text, opacity: 0.7, fontSize: 10, lineHeight: 13},
      axisTick: {show: false},
      axisLine: {lineStyle: {opacity: 0.2}}
    },
    yAxis: {
      type: "value",
      // ⚠ ALWAYS 0 TO 100, NEVER FITTED. The reading is "is it level", and an
      // axis fitted to an 88-to-94 range manufactures a cliff out of six points.
      min: 0,
      max: 100,
      axisLabel: {color: text, opacity: 0.6, formatter: "{value}%"},
      axisLine: {show: false},
      axisTick: {show: false},
      splitLine: {lineStyle: {opacity: 0.12}}
    },
    animationDuration: 480,
    animationEasing: "cubicOut",
    series: [
      {
        type: "custom",
        // ⚠ THE DRAWS HAIRLINE WAS REMOVED ON 2026-08-09, MEASURED OUT RATHER
        // THAN DESIGNED OUT. A second faint rule encoded the share won OR drew,
        // and the gap between the two was meant to be the draws. Live vitals,
        // all five islands: `trials_draws` and `benchmark_draws` are zero in
        // every cell but one, and master flies through the same
        // `engagement:run`. So the hairline sat exactly on top of the rule it
        // was supposed to differ from, in every band, on every island, and cost
        // a legend entry and a caption clause to say nothing.
        //
        // The count is not lost: w/d/l ride in `cells` and appear in the
        // tooltip and the table. A visual channel is spent only on something
        // that varies.
        data: spec.bands.map((_b, i) => [i, spec.won[i], spec.n[i]]),
        markLine: markLine(guide, ink),
        renderItem: (params, api) => {
          const won = api.value(1)
          // A gap draws NOTHING. Not a zero, not a bridge to its neighbours.
          if (!drawn(won) || isNaN(won)) return {type: "group", children: []}

          const i = api.value(0)
          const n = api.value(2)
          const size = api.size([1, 100])
          const w = size[0] - GAP * 2
          const at = api.coord([i, won])
          const base = api.coord([i, 0])
          const x = at[0] - w / 2

          // ⚠ THE RULE NEVER CROSSES THE BASELINE. A measured zero is a rule
          // SITTING ON the axis at full strength, never a zero-height column
          // that reads as a gap. Those are the two states this exhibit keeps
          // having to tell apart.
          const ruleY = Math.min(at[1] - RULE / 2, base[1] - RULE)
          const sure = n >= SURE
          const children = [
            {
              type: "rect",
              shape: {x, y: at[1], width: w, height: Math.max(0, base[1] - at[1])},
              style: {fill: hue, opacity: sure ? 0.1 : 0.05}
            },
            {
              // The edge you read.
              type: "rect",
              shape: {x, y: ruleY, width: w, height: RULE, r: [1.5, 1.5, 1.5, 1.5]},
              style: {fill: hue, opacity: sure ? 1 : 0.42}
            }
          ]

          // Only the two ends carry a number, because those two are what the
          // reading compares. A label on every band is five numbers to read
          // where the shape already said it.
          if (measured.length >= 2 && (i === first || i === last)) {
            children.push({
              type: "text",
              style: {
                x: at[0],
                y: ruleY - 5,
                text: `${won}% · n=${n}`,
                textAlign: "center",
                textVerticalAlign: "bottom",
                fill: text,
                fontFamily: "monospace",
                fontSize: 11,
                opacity: 0.75
              }
            })
          }

          return {type: "group", children}
        }
      }
    ]
  }
}

// The denominator under the tick, because opacity alone is not a number and a
// band decided by two fights must not read as solidly as one decided by twenty.
function tick(n) {
  return n === null || n === undefined ? "·" : `n=${n}`
}

function markLine(guide, ink) {
  if (guide === null) return undefined

  return {
    silent: true,
    symbol: "none",
    lineStyle: {color: ink, opacity: 0.25, width: 1, type: "solid"},
    label: {
      position: "end",
      formatter: "as good as the newest band",
      color: ink,
      opacity: 0.5,
      fontSize: 10
    },
    data: [{yAxis: guide}]
  }
}

// ⚠ EVERY TOKEN THE CHARTS NEED, READ ONCE, IN ONE PLACE.
//
// This exists because the hook grew four separate token-reading closures and two
// of them were silently deleted by an edit meant to remove a third. esbuild does
// not error on an undefined global — it leaves `sides()` as a free identifier
// and the browser throws a ReferenceError at call time, which the hook's own
// error guard then swallowed into a blank box. Every chart on the page was empty
// and the server logs were clean.
//
// One function, taking a reader, so there is one thing to delete by accident and
// the checker can exercise it without a DOM.
export function tokens(read) {
  const get = (name, fallback) => (read(name) || "").trim() || fallback

  return {
    ink: get("--color-base-content", "#666"),
    palette: [1, 2, 3, 4, 5, 6].map((n) => get(`--chart-cat-${n}`, "")).filter(Boolean),
    ramp: [get("--chart-seq-1", "#8ab8dc"), get("--chart-seq-5", "#0f3d61")],
    sides: {
      attacker: get("--side-attacker", "#e2556e"),
      defender: get("--side-defender", "#4c8dff"),
      draw: get("--side-draw", "#8a8a86")
    }
  }
}

// ⚠ A RATE, WHERE A CUMULATIVE TOTAL SAID NOTHING. Grouped bars, one series per
// island, so the question "who is taking genomes right now" is answered by
// comparing heights in the same bin rather than by reading five flat lines.
//
// ⚠⚠ A GAP IS NOT A ZERO. A bin an island has no samples for arrives as null and
// ECharts leaves it blank; a zero would draw a bar of height nought and claim a
// measurement that was never made.
export function ratesOption({spec, colour, text, label}) {
  if (!spec || !Array.isArray(spec.series) || spec.series.length === 0) return null
  if (!Array.isArray(spec.bins) || spec.bins.length === 0) return null

  return {
    color: colour,
    textStyle: {color: text, fontFamily: "inherit"},
    animationDuration: 480,
    animationEasing: "cubicOut",
    grid: {left: 44, right: 12, top: 30, bottom: 26},
    tooltip: {trigger: "axis", axisPointer: {type: "shadow"}},
    legend: {show: true, top: 0, textStyle: {color: text}},
    xAxis: {
      type: "category",
      data: spec.bins.map((_, i) => i),
      show: false
    },
    yAxis: {
      type: "value",
      name: label,
      minInterval: 1,
      axisLabel: {color: text, opacity: 0.6},
      axisLine: {show: false},
      axisTick: {show: false},
      splitLine: {lineStyle: {opacity: 0.12}}
    },
    series: spec.series.map((s) => ({
      name: s.island,
      type: "bar",
      barMaxWidth: 12,
      emphasis: {focus: "series"},
      itemStyle: {borderRadius: [3, 3, 0, 0]},
      data: s.data
    }))
  }
}
