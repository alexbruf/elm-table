// Times Table.coreRowModel on 10,000 rows through Elm ports.
// The Elm side does the work inside the port subscription handler and answers
// through an outgoing port; the clock runs around that single round trip.
const { Elm } = require('./elm-bench.js')

const RUNS = 7

const app = Elm.Bench.init()

function send(command) {
  return new Promise((resolve) => {
    const handler = (answer) => {
      app.ports.response.unsubscribe(handler)
      resolve(answer)
    }
    app.ports.response.subscribe(handler)
    app.ports.request.send(command)
  })
}

function median(numbers) {
  const sorted = [...numbers].sort((a, b) => a - b)
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 0
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle]
}

async function time(command) {
  const timings = []
  let answer = ''
  for (let i = 0; i < RUNS; i++) {
    const start = performance.now()
    answer = await send(command)
    timings.push(performance.now() - start)
  }
  return { answer, min: Math.min(...timings), median: median(timings) }
}

async function main() {
  console.log(await send('prepare'))
  for (const command of ['flat', 'nested']) {
    const result = await time(command)
    console.log(
      `${command.padEnd(7)} rows/flatRows/rowsById: ${result.answer}  ` +
        `min ${result.min.toFixed(1)} ms  median ${result.median.toFixed(1)} ms  ` +
        `(${RUNS} runs)`,
    )
  }
}

main()
