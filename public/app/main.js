import { createApp } from '/vue.js'

import App from "/app/app.js?v=4"
import Card from "/app/card.js?v=4"
import Container from "/app/container.js?v=4"
import Button from "/app/button.js?v=4"
import Modal from "/app/modal.js?v=4"
import FormatNumber from "/app/number.js?v=1"

const worker = new Worker("/worker.js") 

window.worker = worker

function performAnimation(jsonMsg) {
  const { animation, data, player_public_key } = jsonMsg;

  switch (animation) {
    case "NUMBER_FLOAT": {
      const { value, color } = data;
      const playerElm = document.getElementById(player_public_key); 
      const br = playerElm.getBoundingClientRect();
      const floater = document.createElement("div")
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
