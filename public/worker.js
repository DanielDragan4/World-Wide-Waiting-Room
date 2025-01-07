importScripts('/bignumber.js');

let players = {}
let thisPlayer = null;

// Based on how fast the update loop ticks
const NGU_SCALE_FACTOR = 1 / 100

// Update Loop
setInterval(() => {
  Object.keys(players).forEach((public_key) => {
    const this_player = players[public_key]
    players[public_key] = intervalFunc(this_player)
  })

  thisPlayer = intervalFunc(thisPlayer);
}, 10)

// Render Loop
setInterval(() => {
  const leaderboard = Object.values(players).sort(
    (a, b) => new BigNumber(a.time_units).lte(new BigNumber(b.time_units)) ? 1 : -1
  )
  postMessage({ leaderboard, player: thisPlayer })
}, 10)

function intervalFunc(this_player) {
  if (!this_player) return;

  const tps = new BigNumber(this_player.time_units_per_second).multipliedBy(NGU_SCALE_FACTOR)
  const tu = new BigNumber(this_player.time_units)

  const next_tu = tu.plus(tps);

  return {
    ...this_player,
    time_units: next_tu.toString()
  }
}

function syncProcedure(e) {
  // console.log("Syncing", e);
  players = {}

  const { leaderboard, player } = e

  thisPlayer = player

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
