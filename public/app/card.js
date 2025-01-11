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

    toggleIconData(icon) {
      document.querySelector(`#${icon}-icon`).classList.toggle('hidden');
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

    time_units_ps() {
      return this.player.time_units_per_second || new BigNumber(0);
    },

    time_units() {
      return this.player.time_units || new BigNumber(0);
    },

    player_powerup_icons() {
      return this.player.player_powerup_icons;
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
          class="relative"
          v-for="icon in player_powerup_icons" 
        >
          <img 
            :onclick="() => toggleIconData(icon.powerup)"
            :onmouseover="() => toggleIconData(icon.powerup)"
            :onmouseleave="() => toggleIconData(icon.powerup)"
            :src="icon.icon" 
            class="w-[22px]"
          >
          <div :id="icon.powerup + '-icon'" class="absolute text-white bg-black rounded p-1 hidden ease-in flex flex-col max-w-max min-w-48 -left-20 text-center z-[1000]">
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
      <format-number class="font-bold" :number="time_units" /> 
      <h6 class="text-sm">Units</h6>
      
      <format-number class="font-bold" :number="time_units_ps"/>
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
