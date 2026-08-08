#!/usr/bin/env bash
# Look at a page the way a visitor does, and report what a human would notice.
#
# ⚠ THIS EXISTS BECAUSE EVERY VISUAL FAULT ON /dronex WAS FOUND BY A HUMAN
# SENDING A SCREENSHOT. An invisible 48% tint. A marker drawn four rows tall.
# Every chart blank because two functions did not exist, with clean server logs,
# passing tests, passing chart checks and a green CI. And a matrix whose rows
# were upside down, so the diagonal was the anti-diagonal.
#
# `charts_check.mjs` measures a chart's geometry without a browser and catches a
# great deal. It cannot catch a page that never ran the code, and it cannot see
# that a grid is transposed.
#
# Reports the number of chart SVGs, the number of marks inside them, and every
# console error, then writes a full-page screenshot.
#
# Usage: scripts/look_at_the_page.sh [url] [out.png]
set -uo pipefail

URL="${1:-https://beam-campus.net/research/workbench/dronex}"
OUT="${2:-/tmp/dronex.png}"
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"

command -v node >/dev/null || { echo "node is required"; exit 1; }

# Playwright drives a real browser; firefox's own --screenshot hangs on a page
# holding a websocket open, because it waits for a load that never settles.
cd "$HERE/.." || exit 1
[ -d node_modules/playwright ] || npm i --no-audit --no-fund playwright@1.49.1 >/dev/null 2>&1
npx --yes playwright@1.49.1 install firefox >/dev/null 2>&1

node - "$URL" "$OUT" <<'JS'
import {firefox} from "playwright"

const [url, out] = process.argv.slice(2)
const browser = await firefox.launch()
const page = await browser.newPage({viewport: {width: 1500, height: 1100}})

const errors = []
page.on("console", (m) => m.type() === "error" && errors.push(m.text()))
page.on("pageerror", (e) => errors.push("PAGEERROR " + e.message))

await page.goto(url, {waitUntil: "networkidle", timeout: 60000})
// Charts mount on the LiveView join, which lands after the network settles.
await page.waitForTimeout(3500)

const svgs = await page.$$eval("[phx-hook] svg", (n) => n.length)
const marks = await page.$$eval("[phx-hook] svg path, [phx-hook] svg rect", (n) => n.length)

console.log(`chart svgs : ${svgs}`)
console.log(`marks      : ${marks}`)

// ⚠ AN EMPTY CHART IS THE FAILURE THIS IS FOR. A container with no marks is
// what a swallowed ReferenceError looks like from the outside.
const empty = await page.$$eval("[phx-hook]", (els) =>
  els.filter((e) => e.querySelectorAll("svg path, svg rect").length === 0).map((e) => e.id)
)
console.log(`empty      : ${empty.length ? empty.join(", ") : "none"}`)

// The buymeacoffee widget ships a font Firefox rejects; it is not ours.
const ours = errors.filter((e) => !/buymeacoffee|downloadable font/.test(e))
console.log(`errors     : ${ours.length ? ours.slice(0, 5).join(" | ") : "none"}`)

await page.screenshot({path: out, fullPage: true})
await browser.close()
process.exit(empty.length || ours.length ? 1 : 0)
JS
echo "screenshot : $OUT"
