let players = {}


// Based on how fast the update loop ticks
const NGU_SCALE_FACTOR = 1 / 100

// Update Loop
setInterval(() => {
  Object.keys(players).forEach((public_key) => {
    intervalFunc(public_key)
  })
}, 10)

// Render Loop
setInterval(() => {
  const leaderboard = Object.values(players).sort((a, b) => a.time_units <= b.time_units ? 1 : -1)
  postMessage(leaderboard)
}, 10)

function intervalFunc(public_key) {
  const this_player = players[public_key]
  const tps = Number(this_player.time_units_per_second) * NGU_SCALE_FACTOR
  const tu = Number(this_player.time_units)

  const next_tu = tu + tps;

  players[public_key] = {
    ...players[public_key],
    time_units: next_tu
  }
}

function syncProcedure(e) {
  console.log("Syncing", e);
  players = {}

  const { leaderboard } = e

  leaderboard.forEach((p) => {
    let metadata = p.metadata ?? '{}';
    try {
      metadata = JSON.parse(metadata)
    } catch (e) {
      metadata = {};
    }

    players[p.public_key] = {
      ...p,
      metadata
    }
  })
}

onmessage = ({ data: jsonMsg }) => {
  const { event } = jsonMsg;
  switch (event) {
    case "sync": {
      syncProcedure(jsonMsg)
    }
  }
}
