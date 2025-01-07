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
      return this.bigNumber.toNumber().toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    },

    bigRep() {
      const [ value, power ] = this.bigNumber.precision(8).toExponential().split("e+");
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
