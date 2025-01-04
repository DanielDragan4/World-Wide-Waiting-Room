export default {
  props: {
    active: Boolean
  },
  template: `
    <button @click="$emit('click')" v-if="!active" class="border p-2 rounded hover:bg-white hover:text-black text-white bg-[#212126]">
      <slot/>
    </button>
    <button @click="$emit('click')" v-if="active" class="border p-2 rounded bg-white text-black">
      <slot/>
    </button>

  `
}
