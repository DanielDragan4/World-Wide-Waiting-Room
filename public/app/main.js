import { createApp } from '/vue.js'

import App from "/app/app.js?v=10"
import Card from "/app/card.js?v=6"
import Container from "/app/container.js?v=5"
import Button from "/app/button.js?v=5"
import Modal from "/app/modal.js?v=5"
import FormatNumber from "/app/number.js?v=4"

const worker = new Worker("/worker.js") 
let lastSync = null 
let nextSync = null;

function queueSync() {
  nextSync = setTimeout(() => {
    lastSync = new Date();
    htmx.trigger("#sync", "sync");
    nextSync = null;
  }, 1000)
}

setInterval(() => {
  if (lastSync === null || ((new Date() - lastSync) / 1000) >= 10) {
    console.log("Haven't received a sync in 10 seconds, queuing another one.");
    queueSync();
  }
}, 10000);

window.worker = worker

function performAnimation(jsonMsg) {
  const { animation, data, player_public_key } = jsonMsg;

  switch (animation) {
    case "NUMBER_FLOAT": {
      const { value, color } = data;
      const playerElm = document.getElementById(player_public_key); 
      const br = playerElm.getBoundingClientRect();
      const floater = document.createElement("div")
      const speed = Math.max(Math.random() + 0.25, 0.5)

      floater.innerText = `${value ?? 0}`;
      let yPos = br.y
      let steps = data.steps || 200;
      const r = setInterval(() => {
        floater.style.cssText = `position: absolute; color: ${color ?? 'white'}; top: ${yPos}px; left: ${br.x + br.width / 2}px; z-index: 75; opacity: ${steps / 50}`
        yPos -= speed;
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

document.addEventListener("htmx:wsAfterMessage", (wsMsg) => {
  const { detail: { message } } = wsMsg;

  if (!message) return

  let jsonMsg;

  try {
    jsonMsg = JSON.parse(message)
  } catch (e) {
    return
  }

  if (nextSync === null) {
    queueSync();
  }

  const { event } = jsonMsg;
  if (event === 'animation' && document.visibilityState === 'visible') {
    const animations = jsonMsg.animations || []

    animations.forEach((a) => {
      let parsed;
      try {
        parsed = JSON.parse(a);
      } catch(e) {
        return;
      }
      performAnimation(parsed)
    })
    return;
  }

  // console.log(jsonMsg);

  worker.postMessage(jsonMsg) 

  document.dispatchEvent(new CustomEvent("tickEvent", { detail: jsonMsg }))
})

const app = createApp({})

app.component('app', App)
app.component('card', Card)
app.component('container', Container)
app.component('cbutton', Button)
app.component('modal', Modal)
app.component('format-number', FormatNumber)

app.mount('#app')
