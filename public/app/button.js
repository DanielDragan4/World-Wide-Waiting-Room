export default {
  props: {
    active: Boolean,
    extraClasses: String
  },
  template: `
    <button 
      @click="$emit('click')" 
      v-if="!active" 
      class="max-lg:text-xs border p-2 rounded hover:bg-white hover:text-black text-white bg-[#212126] z-50"
      :class="extraClasses"
    >
      <slot/>
    </button>
    <button 
      @click="$emit('click')" 
      v-if="active" 
      class="max-lg:text-xs border p-2 rounded bg-white text-black z-50"
      :class="extraClasses"
    >
      <slot/>
    </button>

  `
}
