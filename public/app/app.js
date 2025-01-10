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
      alterations: {},
      allPowerups: [],
      leaderboard: [],
      discordLink: 'https://discord.gg/vQnnjhQGqu',
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
      powerupSearch: "",
    }
  },

  watch: {
    playerName(name) {
      this.submitForm('/name', { name })
    },

    playerCanAlterUniverse(v) {
      if (v) {
        fetch("/altercosmos")
          .then((x) => x.json())
          .then((x) => {
            this.alterations = x
          })
      }
    }
  },

  computed: {
    achievements() {
      return this.allPowerups.filter((x) => x.is_achievement_powerup);
    },

    powerups() {
      return this.allPowerups
        .filter((x) => !x.is_achievement_powerup)
        .filter((y) => {
          if (!this.powerupSearch) return true;
          return y.name.toLowerCase().includes(this.powerupSearch.toLowerCase()) || y.category.toLowerCase().includes(this.powerupSearch.toLowerCase())
        })
        .sort((a, b) => a.name > b.name ? 1 : -1)
    },

    playerCanAlterUniverse() {
      return this.player.player_can_alter_universe;
    }
  },

  methods: {
    applyChange(alteration_id, increase) {
      this.submitForm('/altercosmos', { alteration_id, increase: increase ? "yes" : "no" });
    },

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

    withinMin(data) {
      const { min, current_value } = data
      return  min < current_value 
    },

    withinMax(data) {
      const { max, current_value } = data
      return  max > current_value 
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
      Welcome to <strong>Idle Cosmos</strong>! A multi-player competitive online idle game. 
      <br/><br/>
      By the end of the in-game timer (currently set to 7 days) be the player online with the most "Units" to win. Use powerups to increase your unit production, sabotage other players' unit production, and protect yourself. The game is played in cycles. At the end of each cycle all progress is reset and the game starts anew.
      <br/><br/>
      The winner of each cycle is given the power to incrementally change one of the foundational mechanics of the game. This changes the game permanently for everyone in future cycles.      
      <br><br>
      Head over to our <a class="font-bold hover:underline" target="_blank" :href="discordLink">Discord</a> if you have any questions or concerns about the game.
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

    <modal title="Alter the Cosmos" :no-close="true" v-if="playerCanAlterUniverse">
      <h1 class="text-center text-lg font-bold">Congratulations, you won this cycle!</h1>
      <p class="mt-2 text-center">
        You can now modify one foundational mechanic in the game. This change will get applied to all other players during the next cycle.
        Choose wisely.
      </p>
      
      <h2 class="text-md text-center font-bold mt-4">Modification Options</h2>
      <div class="grid max-lg:grid-cols-1 lg:grid-cols-2 gap-4 my-4">
        <container class="w-full flex flex-col items-center text-center justify-center space-x-2" v-for="data, alteration of alterations">
          <h1 class="mb-2 font-bold">{{ data.text }}</h1>
          <div class class="flex flex-row items-center space-x-4">
            <cbutton 
              @click="applyChange(alteration, false)"
              v-if="withinMin(data)" 
              >- {{ data.increment }} {{ data.unit }}</cbutton>
            <div v-else></div>
            <div class="flex flex-col items-center">
              <div class="font-bold text-md">{{ data.current_value }}</div>
              <div class="text-sm">Current Modifier</div>
            </div> 
            <cbutton 
              @click="applyChange(alteration, true)"
              v-if="withinMax(data)" 
            >+ {{ data.increment }} {{ data.unit }}</cbutton>
            <div v-else></div>
          </div>
        </container>
      </div>
    </modal>

    <div class="flex flex-col items-center w-full">
      <div class="font-bold text-4xl text-center mt-1">Idle Cosmos</div>
      <a class="font-bold hover:underline" target="_blank" :href="discordLink">Join our Discord</a>
    </div>

    <div class="
      flex 
      max-lg:flex-col 
      max-lg:items-center
      max-lg:w-full
      lg:flex-row 
      lg:items-start 
      lg:justify-between 
      lg:mx-2 
      my-6
    " v-show="player.time_units">
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
              <format-number class="font-bold text-xs" :number="x.units" />
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
                <div class="flex flex-row text-center justify-center space-x-2">
                  <span>Reach</span> 
                  <format-number :number="x.price" /> 
                  <span>units.</span>
                </div>
                <h2 class="text-center">{{ x.description }}</h2>
              </container>
          </container>

          <container v-if="sideContentToShow === 'powerups'" class="flex flex-col items-center justify-between space-y-2 max-h-[600px] overflow-y-auto">
            <h1 class="font-bold text-center">Powerups</h1>
            <input 
              type="search" 
              placeholder="Search"
              class="w-full rounded p-2 text-md text-center bg-[#323237] z-10" 
              v-model="powerupSearch"
            >
            <container 
              v-for="powerup in powerups"
              class="w-full flex flex-col items-center space-y-1"
            >
              <h1 class="text-xl font-bold">{{ powerup.name }}</h1>
              <h2 class="text-xs">{{ powerup.category }}</h2>
              <format-number class="font-bold text-xs" :number="powerup.price" />
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
