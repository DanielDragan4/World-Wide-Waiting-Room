const powerups = {}
const waiterCard = document.querySelector("#waiter-card");
const powerupsContainer = document.querySelector("#powerups");
const timeLeftContainer = document.querySelector("#time-left")

const worker = new Worker("/worker.js") 
let thisPlayerId = null;

// Time Left Interval

function timeLeftFunc() {
  timeLeft--   

  const days = Math.floor(timeLeft / 60 / 60 / 24)
  const hours = Math.floor(timeLeft / 60 / 60 % 24)
  const minutes = Math.floor(timeLeft / 60 % 60);
  const seconds = Math.floor(timeLeft % 60)

  timeLeftContainer.innerText = `${days} days ${hours} hours ${minutes} minutes ${seconds} seconds`
}

function formatTimeString(seconds) {
  if (!seconds) {
    return "0 sec"
  }

  const d = Math.floor(seconds / 60 / 60 / 24)
  const h = Math.floor(seconds / 60 / 60 % 24)
  const m = Math.floor(seconds / 60 % 60)
  const s = Math.floor(seconds % 60)

  let result = ''

  if (d > 0) {
    result += `${d} day `
  }

  if (h > 0) {
    result += `${h} hr `
  }

  if (m > 0) {
    result += `${m} min `
  }

  if (s > 0) {
    result += `${s} sec`
  }

  return result;
}

setInterval(timeLeftFunc, 1000)
timeLeftFunc()

function formatTimeUnits(tu) {
  if (tu < 10000) {
    return tu.toFixed(2)
  }

  let power = 0;
  while (tu > 10) {
    tu /= 10
    power++
  }

  return `<div class="flex flex-row items-center">
    <div>${tu.toFixed(5)}</div>
    <div class="font-light text-[0.8em] mx-2">x</div> 
    <div class="flex flex-row items-start">
      <div>10</div>
      <div class="text-[0.7em] ml-1">${power}</div>
    </div>
  </div>`
}

function performAnimation(jsonMsg) {
  const { animation, data, player_public_key } = jsonMsg;

  switch (animation) {
    case "NUMBER_FLOAT": {
      const { value, color } = data;
      const playerElm = document.getElementById(player_public_key); 
      const br = playerElm.getBoundingClientRect();
      floater = document.createElement("div")
      floater.innerText = `${value ?? 0}`;
      let yPos = br.y
      let steps = 100;
      const r = setInterval(() => {
        floater.style.cssText = `position: absolute; color: ${color ?? 'white'}; top: ${yPos}px; left: ${br.x + br.width / 2}px; z-index: 1000000; opacity: ${steps / 50}`
        yPos -= 0.5;
        steps--;
        if (steps <= 0) {
          floater.remove();
          clearInterval(r); 
        }
      }, 1/30)
      document.body.appendChild(floater);
    }
  }
}

function toggleWhatIsThis() {
  document.querySelector("#what-is-this").classList.toggle("hidden"); 
}

function buy(powerup) {
  const fd = new FormData();
  fd.append("powerup", powerup)
  fetch("/buy", { method: "POST", body: fd })
    .then((x) => x.text())
    .then((r) => {
      console.log(r);
    })
}

function notAvailableString(powerup) {
  if (powerup.cooldown_seconds_left > 0) {
    return formatTimeString(powerup.cooldown_seconds_left)
  }

  return "Not Available";
}

worker.onmessage = ({ data }) => {
  const leaderboard = document.querySelector("#leaderboard");
  const newLeaderboardHtml = document.createElement("div");
  data.forEach((player) => {
    const card = document.createElement("div");
    card.id = player.public_key
    card.innerHTML = `
    <div 
      style="background-color: ${player.bg_color}; color: ${player.text_color}" 
      class="
        relative
        p-4 
        rounded 
        m-2 
        w-[200px]
        h-[200px]
        text-white 
        flex 
        flex-col 
        justify-between
        ${player.player_card_css_classes}
    ">
      <span class="text-2xl text-center">${escape(player.name)}</span>
      <div class="text-center my-auto flex flex-col">
        <span class="font-bold text-xl">
          ${formatTimeUnits(player.time_units)}
        </span>
        <span>Units</span>
        <span class="font-bold text-md mt-2">
          ${player.time_units_per_second.toFixed(2)}
        </span>
        <span>Units/s</span>
        <span>${player.powerups.join(', ')}</span>
      </div>
    </div>`
    newLeaderboardHtml.appendChild(card)

    if (player.public_key === thisPlayerId) {
      waiterCard.innerHTML = card.innerHTML;
      // Defined in index.html originally
      playerCurrentTimeUnits = player.time_units;
    }
  });

  leaderboard.innerHTML = newLeaderboardHtml.innerHTML
}

document.addEventListener("htmx:wsAfterMessage", (wsMsg) => {
  const { detail: { message } } = wsMsg;

  if (!message) return

  let jsonMsg;

  try {
    jsonMsg = JSON.parse(message)
  } catch (e) {
    return
  }

  const { event } = jsonMsg;
  if (event === 'animation') {
    performAnimation(jsonMsg);
    return;
  }

  worker.postMessage(jsonMsg) 

  const { player, time_left, powerups } = jsonMsg;

  // Defined in index.html originally
  timeLeft = time_left

  powerups.forEach((powerup) => {
    const { id } = powerup
    if (!id) return;

    if (JSON.stringify(powerup) !== powerups[id]) {
      powerups[id] = powerup
      const powerupCard = document.createElement("div");
      const buyButton = powerup.is_available_for_purchase && powerup.price <= playerCurrentTimeUnits
      ? `

<button 
name="powerup"
onclick="buy('${id}')"
class="text-white bg-[#212126] border w-full mx-auto p-2 rounded cursor-pointer hover:bg-white hover:text-[#212126]" 
>Buy</button>
      ` : `<div class="w-full text-center text-sm">${notAvailableString(powerup)}</div>`
      powerupCard.id = `powerup-${id}`
      powerupCard.innerHTML = `
<div class="border rounded bg-[#212126] p-4">
<h1 class="text-center font-bold">${powerup.name}</h1>
<h2 class="text-center">${powerup.description}</h1>
<h3 class="text-center font-bold my-4">${powerup.price.toLocaleString('en-US')} units</h3>
${buyButton} 
</div>
      `;

      const powerupContainer = document.querySelector(`#powerup-${id}`);        
      if (!powerupContainer) {
        powerupsContainer.appendChild(powerupCard);
      } else {
        powerupContainer.innerHTML = powerupCard.innerHTML;
      }
    }
  })

  thisPlayerId = player.public_key
})
