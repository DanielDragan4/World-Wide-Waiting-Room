export default {
  props: {
    number: String,
    classes: String,
  },

  computed: {
    bigNumber() {
      return new BigNumber(this.number);
    },

    smallRep() {
      return (this.bigNumber.toNumber() || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    },

    bigRep() {
      let [ value, power ] = this.bigNumber.precision(8).toExponential().split("e+");
      if (value.length <= 8) {
        if (value.length === 1) {
          value = value + '.' + "0".repeat(9 - value.length)
        } else {
          value = value + "0".repeat(9 - value.length)
        }
      }
      return { value, power }    
    },

    isLarge() {
      return this.bigNumber.gt(100_000_000);
    }
  },

  template: `
    <div v-if="!isLarge" :class="classes">{{ smallRep }}</div>
    <div v-else :class="classes">
      <div class="flex flex-row items-center space-x-1">
        <span>{{ bigRep.value }}</span>
        <span>x</span>
        <span>10</span>
        <sup>{{ bigRep.power }}</sup>
      </div>
    </div>
  `
}
