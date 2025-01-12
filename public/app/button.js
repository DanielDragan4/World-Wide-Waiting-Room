export default {
  props: {
    active: Boolean,
    extraClasses: String,
    waitAfterClick: Number,
    textAfterClick: String,
  },

  data() {
    return {
      isWaiting: false, 
    }
  },

  methods: {
    onClick(e) {
      this.$emit("click");

      if (this.waitAfterClick) {
        this.isWaiting = true;
        setTimeout(() => {
          this.isWaiting = false;
        }, this.waitAfterClick)
      }
    }
  },

  template: `
    <button 
      @click="onClick" 
      v-if="!active && !isWaiting" 
      class="max-lg:text-xs border p-2 rounded hover:bg-white hover:text-black text-white bg-[#212126] z-50"
      :class="extraClasses"
    >
      <slot/>
    </button>
    <button 
      @click="onClick" 
      v-if="active && !isWaiting" 
      class="max-lg:text-xs border p-2 rounded bg-white text-black z-50"
      :class="extraClasses"
    >
      <slot/>
    </button>

    <span class="text-center" :class="extraClasses" v-if="isWaiting">{{ textAfterClick }}</span>
  `
}
