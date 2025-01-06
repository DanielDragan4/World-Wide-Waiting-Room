export default {
  mounted() {
    this.fetchHistory();

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
      this.allPowerups = powerups;
    });

    this.secret = window.this_player_secret;
  },

  data() {
    return {
      allPowerups: [],
      leaderboard: [],
      discordLink: '#',
      history: [],
      timeLeft: 0,
      player: {},
      playerName: null,
      textColor: null,
      bgColor: null,
      secret: null,
      newKey: "",
      showWhatIsThis: false,
      showSession: false,
      sideContentToShow: null,
    }
  },

  watch: {
    playerName(name) {
      this.submitForm('/name', { name })
    }
  },

  computed: {
    achievements() {
      return this.allPowerups.filter((x) => x.is_achievement_powerup);
    },

    powerups() {
      return this.allPowerups
        .filter((x) => !x.is_achievement_powerup)
        .sort((a, b) => a.name > b.name ? 1 : -1)
    }
  },

  methods: {
    loadSessionKey() {
      this.submitForm('/login', { key: this.newKey })
        .then((v) => v.text())
        .then((y) => {
          if (y === this.newKey) {
            window.location.reload();
          } else {
            alert("Could not load session.");
          }
        })
    },

    fetchHistory() {
      fetch('/history')
        .then((x) => x.json())
        .then((history) => { 
          history.reverse();
          this.history = history 
        })
    },

    formatNumber(n) {
      return Number(n).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    },

    buy(powerup) {
      this.submitForm('/buy', { powerup })
    },

    usePowerup(powerup, on_player_key) {
      this.submitForm('/use', { powerup, on_player_key })
    },

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
      return fetch(to, { method: 'POST', body })
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
      Welcome to Idle Cosmos! An online competitive idle game. Be the person with the most "Units" by the end of the timer to win.
      Use powerups to increase you Unit generation, sabatoge other players, and protect yourself.
      <br><br>
      Head over to our <a class="font-bold hover:underline" :href="discordLink">Discord</a> if you have any questions or concerns about the game.
      <br><br>
      Good luck!
    </modal>

    <modal title="Session" @close="showSession=false" v-show="showSession" >
      <div class="flex flex-col items-center">
        <h2 class="text-sm text-center">Use this key to duplicate your session across different devices. Do not share this key with anyone! Acquiring this key allows anyone to play as you.</h2>
        <div class="text-xs overflow-y-auto mt-4 p-2 border rounded max-w-[300px] text-center">{{ secret }}</div>

        <div class="flex flex-col space-y-2 mt-4 items-center">
          <h2 class="text-md">Load Key</h2>
          <input 
            class="rounded p-2 text-2xl text-center bg-[#323237] z-10" 
            type="text" 
            placeholder="Session Key" 
            v-model="newKey"
          >
          <cbutton @click="loadSessionKey()">Load</cbutton>
        </div>
      </div>
    </modal>

    <div class="flex flex-col items-center w-full">
      <div class="font-bold text-4xl text-center mt-1">Idle Cosmos</div>
      <a class="font-bold hover:underline" :href="discordLink">Join our Discord</a>
    </div>

    <div class="
      flex 
      max-lg:flex-col 
      max-lg:items-center
      max-lg:w-full
      lg:flex-row 
      lg:items-start 
      lg:justify-between 
      mx-2 
      my-6
    " v-show="player.time_units !== undefined">
      <div class="max-lg:w-full">
        <div class="flex flex-col space-y-2 lg:absolute lg:w-96 max-lg:w-full lg:top-2 lg:left-2">
          <container class="text-sm text-center">{{ formatTimeString(timeLeft) }}</container>
          <div class="w-full flex flex-col space-y-2">
            <cbutton 
              @click="sideContentToShow=(sideContentToShow !== 'powerups' ? 'powerups' : null)"
              :active="sideContentToShow == 'powerups'"
            >Powerups</cbutton>
            <cbutton 
              @click="sideContentToShow=(sideContentToShow !== 'achievements' ? 'achievements' : null)"
              :active="sideContentToShow == 'achievements'"
            >Achievements</cbutton>
            <cbutton 
              @click="fetchHistory(); sideContentToShow=(sideContentToShow !== 'history' ? 'history' : null)"
              :active="sideContentToShow == 'history'"
            >Leaderboard</cbutton>
          </div>

          <container v-if="sideContentToShow === 'history'" class="flex flex-col items-center justify-between space-y-2 max-h-[600px] overflow-y-auto">
            <h1 class="font-bold text-center">Leaderboard</h1>
            <h2 class="text-sm text-center">Previous game winners.</h2>
            <container class="grid grid-cols-3 text-center w-full">
              <span class="font-bold text-sm">Player</span>
              <span class="font-bold text-sm">Final Units</span>
              <span class="font-bold text-sm">Timestamp</span>
            </container>
            <container 
              v-for="x in history"
              class="grid grid-cols-3 text-center w-full items-center"
            >
              <span class="font-bold text-sm">{{ x.name }}</span>
              <span class="font-bold text-sm">{{ formatNumber(x.units) }}</span>
              <span class="font-bold text-sm">{{ x.date }}</span>
            </container>
          </container>

          <container v-if="sideContentToShow === 'achievements'" class="flex flex-col items-center justify-between space-y-2 max-h-[600px] overflow-y-auto">
            <h1 class="font-bold text-center">Achievements</h1>
            <container 
              v-for="x in achievements"
              class="w-full text-center"
              :class="{ 'bg-white text-black':  player.powerups.includes(x.id) }"
            >
                <h1 class="font-bold text-xl">{{ x.name }}</h1>
                <h2 v-html="x.description"></h2>
              </container>
          </container>

          <container v-if="sideContentToShow === 'powerups'" class="flex flex-col items-center justify-between space-y-2 max-h-[600px] overflow-y-auto">
            <h1 class="font-bold text-center">Powerups</h1>
            <container 
              v-for="powerup in powerups"
              class="w-full flex flex-col items-center space-y-1"
            >
              <h1 class="text-xl font-bold">{{ powerup.name }}</h1>
              <h2 class="text-xs">{{ powerup.category }}</h2>
              <h3 class="text-sm font-bold">\${{ formatNumber(powerup.price) }}</h3>
              <div class="my-2 text-center" v-html="powerup.description"></div>
              <cbutton @click="buy(powerup.id)" v-if="powerup.is_available_for_purchase">Buy</cbutton>
              <div v-else-if="powerup.cooldown_seconds_left > 0" class="flex flex-col text-center">
                <span>Next purchase</span>
                <strong>{{ formatTimeString(powerup.cooldown_seconds_left) }}</strong>
              </div>
              <div v-else-if="powerup.currently_owns">Purchased</div>
              <div v-else>Unavailable</div>
            </container>
          </container>
        </div>
      </div>
      <div class="flex flex-row space-x-2 max-lg:w-full max-lg:mt-2 lg:absolute lg:top-2 lg:right-2">
        <cbutton
          extra-classes="max-lg:w-full"
          :active="showSession"
          @click="showSession = !showSession"
        >Session</cbutton>
        <cbutton 
          extra-classes="max-lg:w-full"
          :active="showWhatIsThis"
          @click="showWhatIsThis = !showWhatIsThis">What is this?</cbutton>
      </div>
    </div>

    <div class="flex flex-col items-center space-y-2 w-96 mx-auto" v-show="player.time_units !== undefined">
      <h2 class="text-xl text-center">Name</h2>
      <input @input="updateName" class="rounded p-2 text-2xl text-center bg-[#323237] z-10" v-model="playerName">
      <div class="flex flex-row justify-center">
        <div class="flex flex-col items-center w-32">
          <input @change="updateTextColor" type="color" class="z-50 border-none bg-transparent w-[32px] h-[32px]" v-model="textColor">
          <span class="text-sm">Text Color</span>
        </div>
        <div class="flex flex-col items-center w-32">
          <input @change="updateBgColor" type="color" class="z-50 border-none bg-transparent w-[32px] h-[32px]" v-model="bgColor">
          <span class="text-sm">Background Color</span>
        </div>
      </div>
      <card
        :player="player"
        :this-player="player"
      />
    </div>

    <h1 class="font-bold text-center mt-6" v-show="player.time_units !== undefined">Online Players</h1>
    <div class="mt-2 flex flex-row w-full mx-auto flex-wrap justify-center pb-8">
      <card
        v-for="p, i in leaderboard"
        @activate-input="usePowerup($event, p.public_key)"
        :this-player="player"
        :player="p"
        :place="i"
        class="m-2"
      />
    </div>
  `
}
