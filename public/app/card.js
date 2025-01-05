export default {
  props: {
    thisPlayer: Object,
    place: Number,
    player: Object
  },

  methods: {
    popupInfo(pu) {
      const info = this.player.popup_info[pu];

      if (!pu) {
        return "";
      }

      return Object.entries(info)
    },
  },

  computed: {
    this_player_public_key() {
      return this.thisPlayer.public_key;
    },

    public_key() {
      return this.player.public_key;
    },

    current_place() {
      if (typeof this.place === 'number') {
        return this.place + 1
      }

      return null;
    },

    time_units() {
      return this.player.time_units || 0;
    },

    time_units_small() {
      const tu = this.time_units;
      return tu.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    },

    player_powerup_icons() {
      return this.player.player_powerup_icons;
    },

    time_units_large() {
      let tu = this.time_units
      let power = 0;

      while (tu > 10) {
        tu /= 10
        power++
      }

      return { time_units: tu.toFixed(5), power }
    },

    time_units_ps() {
      return Number(this.player.time_units_per_second).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) 
    },

    player_css_classes() {
      return this.player.player_css_classes || '';
    },

    input_buttons() {
      return this.thisPlayer.input_buttons || [];
    }
  },
  template: `
  <div 
    :id="public_key"
    :class="player_css_classes"
    class="
      z-10
      w-[300px] 
      h-[300px] 
      border 
      p-2 
      rounded
      flex flex-col items-center justify-between text-center relative
    " 
    :style="{ 'color': player.text_color, 'background-color': player.bg_color }">
    <div class="flex flex-col items-center">
      <div v-show="current_place" class="absolute top-2 left-2 text-xs">#{{ current_place }}</div>
      <h1 class="text-xl">{{ player.name }}</h1>
      <div class="flex flex-row justify-center space-x-2">
        <div 
          class="relative group"
          v-for="icon in player_powerup_icons" 
        >
          <img 
            :src="icon.icon" 
            class="w-[22px]"
          >
          <div class="absolute text-white bg-black rounded p-1 invisible group-hover:visible ease-in flex flex-col max-w-48 min-w-48 -left-20 text-center">
            <h3>{{ icon.name }}</h3>
            <div class="flex flex-col space-y-1 items-center">
              <div v-for="[k, v] in popupInfo(icon.powerup)" class="flex flex-row space-x-2">
                <span class="font-bold">{{ k }}:</span>
                <span>{{ v }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="text-center">
      <div v-if="time_units < 100_000_000" class="text-lg font-bold">{{ time_units_small }}</div>
      <div class="flex flex-row items-center space-x-2 font-bold" v-else>
        <span>{{ time_units_large.time_units }}</span>
        <span>x</span>
        <span>10</span>
        <sup>{{ time_units_large.power }}</sup>
      </div>
      <h6 class="text-sm">Units</h6>
      
      <div class="text-md font-bold mt-4">{{ time_units_ps }}</div>
      <h6 class="text-sm">Units/s</h6>
    </div>

    <div class="flex flex-row space-x-2 items-center">
      <cbutton 
        v-if="public_key !== this_player_public_key"
        v-for="x in input_buttons"
        @click="$emit('activate-input', x.value)"
      >{{ x.name }}</cbutton> 
    </div>
  </div>
  `
}
