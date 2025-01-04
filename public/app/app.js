export default {
  mounted() {
    window.worker.onmessage = ({ data: { leaderboard, player } }) => {
      if (player) {
        if (this.playerName === null) {
          this.playerName = player.name;
        }

        if (this.textColor === null) {
          this.textColor = player.text_color;
        }

        if (this.bgColor === null) {
          this.bgColor = player.bg_color;
        }
        this.player = { ...player };
      }

      this.leaderboard = [...leaderboard];
    }
  
    document.addEventListener("tickEvent", ({ detail: { player, time_left, powerups } }) => {
      this.timeLeft = time_left; 
      this.powerups = powerups;
    });
  },

  data() {
    return {
      leaderboard: [],
      timeLeft: 0,
      powerups: [],
      player: {},
      playerName: null,
      textColor: null,
      bgColor: null,
      showWhatIsThis: false,
      sideContentToShow: null,
    }
  },

  watch: {
    playerName(name) {
      this.submitForm('/name', { name })
    }
  },

  methods: {
    updateTextColor() {
      const text = this.textColor;
      this.submitForm('/color', { text })
    },

    updateBgColor() {
      const bg = this.bgColor
      this.submitForm('/color', { bg })
    },

    submitForm(to, values) {
      const body = new FormData();
      Object.entries(values).forEach(([k, v]) => {
        body.append(k, v)
      })
      fetch(to, { method: 'POST', body })
    },

    formatTimeString(seconds) {
      if (!seconds) {
        return "Done"
      }

      const d = Math.floor(seconds / 60 / 60 / 24)
      const h = Math.floor(seconds / 60 / 60 % 24)
      const m = Math.floor(seconds / 60 % 60)
      const s = Math.floor(seconds % 60)

      return `${d} day ${h} hr ${m} min ${s} sec`
    }
  },
  template:`
    <modal title="What is this?" @close="showWhatIsThis=false" v-show="showWhatIsThis">
      Nice
    </modal>

    <div class="flex flex-row items-start justify-between mx-2 my-6">
      <div class="flex flex-col space-y-2">
        <container class="text-sm text-center">{{ formatTimeString(timeLeft) }}</container>
        <cbutton 
          @click="sideContentToShow=(sideContentToShow !== 'powerups' ? 'powerups' : null)"
          :active="sideContentToShow == 'powerups'"
        >Powerups</cbutton>
        <cbutton 
          @click="sideContentToShow=(sideContentToShow !== 'achievements' ? 'achievements' : null)"
          :active="sideContentToShow == 'achievements'"
        >Achievements</cbutton>
      </div>
      <span class="font-bold text-4xl">Idle Royale</span>
      <cbutton 
        :active="showWhatIsThis"
        @click="showWhatIsThis = !showWhatIsThis">What is this?</cbutton>
    </div>

    <div class="flex flex-col items-center space-y-2 w-96 mx-auto">
      <h2 class="text-xl text-center">Name</h2>
      <input @input="updateName" class="rounded p-2 text-2xl text-center bg-[#323237] z-10" v-model="playerName">
      <div class="flex flex-row justify-center">
        <div class="flex flex-col items-center w-32">
          <input @change="updateTextColor" type="color" class="border-none bg-transparent w-[32px] h-[32px]" v-model="textColor">
          <span class="text-sm">Text Color</span>
        </div>
        <div class="flex flex-col items-center w-32">
          <input @change="updateBgColor" type="color" class="border-none bg-transparent w-[32px] h-[32px]" v-model="bgColor">
          <span class="text-sm">Background Color</span>
        </div>
      </div>
      <card
        :player="player"
      />
    </div>

    <h1 class="font-bold text-center mt-6">Leaderboard</h1>
    <div class="mt-2 flex flex-row w-full mx-auto flex-wrap justify-center">
      <card
        v-for="player in leaderboard"
        :player="player"
        class="m-2"
      />
    </div>
  `
}
