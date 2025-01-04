import { createApp, ref } from 'https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js'

import App from "/app/app.js"
import Card from "/app/card.js"
import Container from "/app/container.js"
import Button from "/app/button.js"
import Modal from "/app/modal.js"

const worker = new Worker("/worker.js") 

window.worker = worker

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

  console.log(jsonMsg);

  worker.postMessage(jsonMsg) 

  document.dispatchEvent(new CustomEvent("tickEvent", { detail: jsonMsg }))
})

const app = createApp({})

app.component('app', App)
app.component('card', Card)
app.component('container', Container)
app.component('cbutton', Button)
app.component('modal', Modal)

app.mount('#app')
