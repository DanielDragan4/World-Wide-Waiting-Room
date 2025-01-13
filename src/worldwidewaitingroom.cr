require "kemal"
require "big"
require "random"
require "json"
require "redis"
require "base64"
require "./powerups/bootstrap.cr"
require "./powerups/timewarp.cr"
require "./powerups/overcharge.cr"
require "./powerups/harvest.cr"
require "./powerups/unit_multiplier.cr"
require "./powerups/tedious_gains.cr"
require "./powerups/amish_life.cr"
require "./powerups/relativistic_shift.cr"
require "./powerups/blackhole.cr"

require "./powerups/parasite.cr"
require "./powerups/breach.cr"
require "./powerups/signal_jammer.cr"
require "./powerups/force_field.cr"
require "./powerups/afflict_breach.cr"
require "./powerups/afflict_signal_jammer.cr"
require "./powerups/synergy_matrix.cr"
require "./powerups/compound_interest"
require "./powerups/force_field"
require "./powerups/breach"
require "./powerups/signal_jammer"
require "./powerups/automation_upgrade.cr"
require "./powerups/schrodinger"
require "./powerups/cosmic_breakthrough"
require "./powerups/unit_vault"
require "./powerups/boost_sync"
require "./powerups/afflict_black_hole"
require "./powerups/necrovoid"


require "./powerups/achievement_type_1.cr"
require "./powerups/achievement_type_2.cr"
require "./powerups/achievement_type_3.cr"
require "./powerups/achievement_type_4.cr"
require "./powerups/achievement_type_5.cr"

require "./templates"

alias Secret = String
alias Public = String
alias ChannelValueType = String

templates = Templates.new

ONE_WEEK = 604800

class Alterations
  property game_duration : Float64
  property base_units_per_second : Float64
  property active_price : Float64
  property passive_price : Float64
  property defensive_price : Float64
  property sabotage_price : Float64
  property achievement_goal : Float64

  def initialize(
    @game_duration : Float64,
    @base_units_per_second : Float64,
    @active_price : Float64,
    @passive_price : Float64,
    @defensive_price : Float64,
    @sabotage_price : Float64,
    @achievement_goal : Float64
  ) end

end

module WWWR
  R = Redis::PooledClient.new
  Channels = Set(Tuple(String, Channel(ChannelValueType), Public)).new
end

enum Animation
  NUMBER_FLOAT
end

module Events
  def self.animation (public_key : String, animation : Animation, data) : String
    {
      "player_public_key" => public_key,
      "animation" => animation.to_s,
      "data" => data
    }.to_json
  end

  def self.sync (leaderboard, player_data, powerups, time_left, universe_change_log) : String
    {
      "event" => "sync",
      "leaderboard" => leaderboard,
      "time_left" => time_left,
      "player" => player_data,
      "universe_change_log" => universe_change_log,
      "powerups" => powerups
    }.to_json
  end
end

module Keys
  GAME_WINNERS = "game_winners"
  PLAYER_POWERUP_ICONS = "player_powerup_icons"
  PLAYER_CARD_CSS_CLASSES = "player_card_css_classes"
  NUMBER_OF_ACTIVES = "number_of_actives_purchased_ever"
  UNIT_GEN_DISABLED = "unit_gen_disabled"
  TIME_LEFT = "time_left"
  COOKIE = "token"
  UNIVERSE_CHANGE_LOG = "universe_change_log"
  PLAYER_CAN_ALTER_UNIVERSE = "player_can_alter_universe"
  GLOBAL_VARS = "global_vars"
  LAST_FRAME_TIME = "frame_time"
  LEADERBOARD = "online-leaderboard"
  NECROVOIDERS = "necrovoiders"
  PLAYER_PUBLIC_KEY = "public_key"
  PLAYER_POWERUPS = "powerups"
  PLAYER_METADATA = "metadata"
  PLAYER_TOKENS = "tokens"
  PLAYER_TIME_UNITS = "time_units"
  BUY_RATE_LIMIT = "buy_rate_limit"

  ALTERATION_GAME_DURATION = "alteration_game_duration"
  ALTERATION_BASE_RATE = "alteration_base_units_per_second"
  ALTERATION_ACHIEVEMENT_GOAL = "alteration_achievement_goal"

  ALTERATION_ACTIVE_PRICE = "alteration_active_price"
  ALTERATION_PASSIVE_PRICE = "alteration_passive_price"
  ALTERATION_SABOTAGE_PRICE = "alteration_sabotage_price"
  ALTERATION_DEFENSIVE_PRICE = "alteration_defensive_price"

  # PLAYER_FRAME_TUPS is the value that is visually present in the UI. PLAYER_TIME_UNITS_PER_SECOND is the manipulatable value
  # The reason for needing both is that at the end of a frame the PLAYER_TIME_UNITS_PER_SECOND is not an accurate representation
  # of the player's TUPS for that frame.
  # PLAYER_FRAME_TUPS contains the correct value for that frame.

  PLAYER_FRAME_TUPS = "frame_time_units_per_second"
  PLAYER_TIME_UNITS_PER_SECOND = "time_units_per_second"

  PLAYER_NAME = "name"
  PLAYER_POWERUP_POPUP_INFO = "popup_info"
  PLAYER_INPUT_BUTTONS = "input_buttons"
  PLAYER_BG_COLOR = "bg_color"
  PLAYER_TEXT_COLOR = "text_color"
  COOLDOWN = "bootstrap_cooldown"
end

class Game
  @sync_next_frame = false
  @default_ups = 1

  @time_units_cache = Hash(Public, BigFloat).new
  @time_units_ps_cache = Hash(Public, BigFloat).new

  @universe_change_log : Array(Hash(String, String)) | Nil = nil
  @alterations : Alterations

  @last_buy = Hash(Public, BigFloat).new

  @animation_queue = Array(String).new

  def can_buy(public_key : Public) : Bool
    last_buy = @last_buy.fetch public_key, BigFloat.new 0

    if (Time.utc.to_unix_ms - last_buy) < 100
      false
    else
      @last_buy[public_key] = BigFloat.new Time.utc.to_unix_ms
      true
    end
  end

  def initialize
    @alterations = get_alterations
  end

  def spawn_loop
    update_frame_time
    spawn do
      loop do
        begin
          tick
        rescue e
          puts "ERROR DURING TICK #{e}"
          e.backtrace.each { |line| puts line }
        end
        # WARNING:
        # DO NOT CHANGE THE SLEEP TIME
        # DOING SO WILL FUCK UP ACTION TIMING
        # SOME POWERUPS DEPEND ON THEIR ACTION BEING CALLED EVERY SECOND
        sleep 1.second
      end
    end
  end

  def tick
    dt = frame_dt_ms
    puts "Last frame #{dt}ms"

    if get_time_left <= 1
      reset_game
    end

    multiplier = BigFloat.new (dt / 1000.0)

    WWWR::R.incrby Keys::TIME_LEFT, -1
    get_time_left

    altered_ups = @alterations.base_units_per_second

    get_leaderboard.each do |player_data|
      player_public_key = player_data["public_key"].to_s

      set_player_time_units_ps player_public_key, BigFloat.new (@default_ups + altered_ups)
      do_powerup_actions player_public_key, dt

      if !(is_unit_generation_disabled_for player_public_key)
        player_tups = get_player_time_units_ps player_public_key
        WWWR::R.hset Keys::PLAYER_FRAME_TUPS, player_public_key, player_tups
        inc_time_units player_public_key, player_tups * multiplier
      else
        WWWR::R.hset Keys::PLAYER_FRAME_TUPS, player_public_key, 0
      end

      do_powerup_cleanup player_public_key
    end

    broadcast_animation_event
    update_frame_time
  end

  def get_universe_change_log
    if @universe_change_log != nil
      return @universe_change_log
    end

    cache_universe_change_log

    if @universe_change_log
      @universe_change_log
    else
      Array(Hash(String, String)).new
    end
  end

  def is_player_online (public_key : String) : Bool
    is_online = false
    WWWR::Channels.each do |x|
      if x[2] == public_key
        is_online = true
      end
    end

    is_online
  end

  def cache_universe_change_log
    change_log = WWWR::R.lrange Keys::UNIVERSE_CHANGE_LOG, 0, -1
    @universe_change_log = change_log.map { |x| Hash(String, String).from_json (x.to_s) }
  end

  def increase_number_by_percentage (number : BigFloat, by : BigFloat) : BigFloat
    number + (number * (by / 100))
  end

  def log_universe_change(public_key : String, change : String)
    date = Time.utc.to_unix.to_s
    json_data = { "public_key" => public_key, "player_name" => (get_player_name public_key), "change" => change, "timestamp" => date }.to_json
    WWWR::R.rpush Keys::UNIVERSE_CHANGE_LOG, json_data
    cache_universe_change_log
  end

  def get_alteration_options
    {
      Keys::ALTERATION_GAME_DURATION => { "name" => "Cycle Length", "text" => "Alter cycle duration by", "unit" => "days", "increment" => 1, "min" => -6, "max" => 7, "current_value" => @alterations.game_duration },
      Keys::ALTERATION_BASE_RATE => { "name" => "Base Unit/s Rate", "text" => "Alter base units per second by", "unit" => "units", "increment" => 0.1, "min" => 0.1, "max" => 1_000_000, "current_value" => @alterations.base_units_per_second },
      Keys::ALTERATION_ACHIEVEMENT_GOAL => { "name" => "Achievement Goals", "text" => "Alter achievement goals by", "unit" => "%", "increment" => 1, "min" => -50, "max" => 50, "current_value" => @alterations.achievement_goal },
      Keys::ALTERATION_PASSIVE_PRICE => { "name" => "Passive Powerup Prices", "text" => "Alter PASSIVE powerup price by", "unit" => "%", "min" => -10, "max" => 10, "increment" => 1, "current_value" => @alterations.passive_price },
      Keys::ALTERATION_ACTIVE_PRICE => { "name" => "Active Powerup Prices", "text" => "Alter ACTIVE powerup price by", "unit" => "%", "min" => -10, "max" => 10, "increment" => 1, "current_value" => @alterations.active_price},
      Keys::ALTERATION_DEFENSIVE_PRICE => { "name" => "Defensive Powerup Prices", "text" => "Alter DEFENSIVE powerup price by", "unit" => "%", "min" => -10, "max" => 10, "increment" => 1, "current_value" => @alterations.defensive_price },
      Keys::ALTERATION_SABOTAGE_PRICE => { "name" => "Sabotage Powerup Prices", "text" => "Alter SABOTAGE powerup price by", "unit" => "%", "min" => -10, "max" => 10, "increment" => 1, "current_value" => @alterations.sabotage_price },
    }
  end

  def set_alterations
    @alterations = get_alterations
  end

  def get_cached_alterations
    @alterations
  end

  def get_alterations
    alter_base_units_per_second_by = Redis::Future.new
    alter_game_duration_by = Redis::Future.new
    alter_active_price_by = Redis::Future.new
    alter_passive_price_by = Redis::Future.new
    alter_sabotage_price_by = Redis::Future.new
    alter_defensive_price_by = Redis::Future.new
    alter_achievement_goal_by = Redis::Future.new

    WWWR::R.pipelined do |r|
      alter_base_units_per_second_by = r.get(Keys::ALTERATION_BASE_RATE)
      alter_game_duration_by = r.get(Keys::ALTERATION_GAME_DURATION)
      alter_active_price_by = r.get(Keys::ALTERATION_ACTIVE_PRICE)
      alter_passive_price_by = r.get(Keys::ALTERATION_PASSIVE_PRICE)
      alter_sabotage_price_by = r.get(Keys::ALTERATION_SABOTAGE_PRICE)
      alter_defensive_price_by = r.get(Keys::ALTERATION_DEFENSIVE_PRICE)
      alter_achievement_goal_by = r.get(Keys::ALTERATION_ACHIEVEMENT_GOAL)
    end

    game_duration = alter_game_duration_by.value.to_s.to_f64?
    game_duration ||= 0.0

    base_units_per_second = alter_base_units_per_second_by.value.to_s.to_f64?
    base_units_per_second ||= 0.0

    active_price = alter_active_price_by.value.to_s.to_f64?
    active_price ||= 0.0

    passive_price = alter_passive_price_by.value.to_s.to_f64?
    passive_price ||= 0.0

    sabotage_price = alter_sabotage_price_by.value.to_s.to_f64?
    sabotage_price ||= 0.0

    defensive_price = alter_defensive_price_by.value.to_s.to_f64?
    defensive_price ||= 0.0

    achievement_goal = alter_achievement_goal_by.value.to_s.to_f64?
    achievement_goal ||= 0.0

    Alterations.new(
      game_duration,
      base_units_per_second,
      active_price,
      passive_price,
      defensive_price,
      sabotage_price,
      achievement_goal,
    )

  end

  def get_powerup_classes
    {
      PowerupBootStrap.get_powerup_id => PowerupBootStrap.new(self),
      PowerupTimeWarp.get_powerup_id => PowerupTimeWarp.new(self),
      PowerupOverCharge.get_powerup_id => PowerupOverCharge.new(self),
      PowerupHarvest.get_powerup_id => PowerupHarvest.new(self),
      PowerupUnitMultiplier.get_powerup_id => PowerupUnitMultiplier.new(self),
      PowerupAmishLife.get_powerup_id => PowerupAmishLife.new(self),
      PowerupTediousGains.get_powerup_id => PowerupTediousGains.new(self),
      PowerupNecrovoid.get_powerup_id => PowerupNecrovoid.new(self),
      PowerupParasite.get_powerup_id => PowerupParasite.new(self),
      PowerupCompoundInterest.get_powerup_id => PowerupCompoundInterest.new(self),
      PowerupSynergyMatrix.get_powerup_id => PowerupSynergyMatrix.new(self),
      PowerupSignalJammer.get_powerup_id => PowerupSignalJammer.new(self),
      PowerupForceField.get_powerup_id => PowerupForceField.new(self),
      PowerupBreach.get_powerup_id => PowerupBreach.new(self),
      PowerupAutomationUpgrade.get_powerup_id => PowerupAutomationUpgrade.new(self),
      PowerupSchrodinger.get_powerup_id => PowerupSchrodinger.new(self),
      PowerupCosmicBreak.get_powerup_id => PowerupCosmicBreak.new(self),
      PowerupUnitVault.get_powerup_id => PowerupUnitVault.new(self),
      PowerupRelativisticShift.get_powerup_id => PowerupRelativisticShift.new(self),
      PowerupBoostSync.get_powerup_id => PowerupBoostSync.new(self),
      PowerupBlackHole.get_powerup_id => PowerupBlackHole.new(self),

      AfflictPowerupSignalJammer.get_powerup_id => AfflictPowerupSignalJammer.new(self),
      AfflictPowerupBreach.get_powerup_id => AfflictPowerupBreach.new(self),
      AfflictPowerupBlackHole.get_powerup_id => AfflictPowerupBlackHole.new(self),

      AchievementTypeI.get_powerup_id => AchievementTypeI.new(self),
      AchievementTypeII.get_powerup_id => AchievementTypeII.new(self),
      AchievementTypeIII.get_powerup_id => AchievementTypeIII.new(self),
      AchievementTypeIV.get_powerup_id => AchievementTypeIV.new(self),
      AchievementTypeV.get_powerup_id => AchievementTypeV.new(self),
    }
  end

  def get_time_left
    alter_game_duration_by = (@alterations.game_duration * 60 * 60 * 24) # alter by number of days

    tl = WWWR::R.get Keys::TIME_LEFT
    if !tl || tl.to_i <= 0
      WWWR::R.set Keys::TIME_LEFT, ONE_WEEK
      return ONE_WEEK + alter_game_duration_by
    else
      return tl.to_i + alter_game_duration_by
    end
  end

  def get_serialized_powerups (public_key)
    powerups = [] of Hash(String, String | Bool | Int32)
    player_powerups = get_player_powerups public_key

    get_powerup_classes.each do |key, value|
      if value.is_afflication_powerup (public_key)
        next
      end

      begin
        powerups << {
          "id" => key,
          "name" => value.get_name,
          "description" => (value.get_description public_key),
          "price" => (value.get_price public_key).to_s,
          "is_available_for_purchase" => (value.is_available_for_purchase public_key),
          "is_input_powerup" => (value.is_input_powerup public_key),
          "is_achievement_powerup" => (value.is_achievement_powerup public_key),
          "category" => (value.category).to_s,
          "input_button_text" => (value.input_button_text public_key),
          "cooldown_seconds_left" => (value.cooldown_seconds_left public_key),
          "currently_owns" => (player_powerups.includes? key),
        }
      rescue e
        puts e.backtrace.join "\n"
        puts "POWERUP SERIALIZATION ERROR: Failed to serialize powerup #{key} with error #{e}"
      end
    end

    powerups
  end

  def is_unit_generation_disabled_for(public_key : String) : Bool
    !!(WWWR::R.hget Keys::UNIT_GEN_DISABLED, public_key)
  end

  def enable_unit_generation(public_key : String)
    WWWR::R.hdel Keys::UNIT_GEN_DISABLED, public_key
  end

  def disable_unit_generation(public_key : String)
    WWWR::R.hset Keys::UNIT_GEN_DISABLED, public_key, 1
  end

  def do_powerup_actions (public_key : String, dt)
    powerup_classes = get_powerup_classes

    (get_player_powerups public_key).each do |powerup_name|
      powerup_class = powerup_classes.fetch powerup_name, nil
      if powerup_class
        begin
          powerup_class.action public_key, dt
        rescue e
          puts "#{e.backtrace}"
          puts "POWERUP ACTION ERROR: Failed to execute powerup #{powerup_class.get_name} with error #{e}. Skipping."
        end
      end
    end

    powerup_classes.each_value do |pc|
      if pc.is_achievement_powerup public_key
        begin
          pc.action public_key, dt
        rescue e
          puts "ACHIEVEMENT ACTION ERROR: Failed to execute achievement #{pc.get_name} with error #{e}. Skipping."
        end
      end
    end
  end

  def do_powerup_cleanup (public_key : String)
    powerup_classes = get_powerup_classes
    (get_player_powerups public_key).each do |powerup_name|
      powerup_class = powerup_classes.fetch powerup_name, nil
      if powerup_class
        begin
          powerup_class.cleanup public_key
        rescue e
          puts "POWERUP CLEANUP ERROR: Failed to execute powerup cleanup #{powerup_class.get_name} with error #{e}. Skipping."
        end
      end
    end

    powerup_classes.each_value do |pc|
      if pc.is_achievement_powerup public_key
        begin
          pc.cleanup public_key
        rescue e
          puts "POWERUP ACHIEVEMENT CLEANUP ERROR: Failed to execute achievement cleanup #{pc.get_name} with error #{e}. Skipping."
        end
      end
    end
  end

  def format_time (tl) : String
    tl = tl.to_i
    seconds = tl % 60
    minutes = (tl // 60) % 60
    hours = (tl // 60 // 60) % 24
    days = tl // 60 // 60 // 24

    if days > 0
      "#{days}d #{hours}h #{minutes}m #{seconds}s"
    elsif hours > 0
      "#{hours}h #{minutes}m #{seconds}s"
    elsif minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  def update_frame_time
    WWWR::R.set(Keys::LAST_FRAME_TIME, Time.utc.to_unix_ms)
  end

  def format_time (tl) : String
    tl = tl.to_i
    seconds = tl % 60
    minutes = (tl // 60) % 60
    hours = (tl // 60 // 60) % 24
    days = tl // 60 // 60 // 24

    if days > 0
      "#{days}d #{hours}h #{minutes}m #{seconds}s"
    elsif hours > 0
      "#{hours}h #{minutes}m #{seconds}s"
    elsif minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  def get_leaderboard
    get_raw_leaderboard.map { |public_key| get_data_for public_key.to_s }
  end

  def get_leaderboard_index (public_key : String) : Int32 | Nil
    get_raw_leaderboard.index do |pk|
      pk.to_s == public_key
    end
  end

  def get_leaderboard_position (public_key : String) : Int32 | Nil
    i = get_leaderboard_index public_key

    if i
      i + 1
    else
      nil
    end
  end

  def get_player_to_left_and_right (public_key : String) : Tuple(String | Nil, String | Nil)
    player_index = get_leaderboard_index public_key
    raw_leaderboard = get_raw_leaderboard
    # Leaderboard is in reverse order so left and write are "swapped"
    if player_index
      left_i = (player_index + 1)
      right_i = Math.max (player_index - 1), 0

      puts "Player Index #{player_index} Left Index #{left_i} Right Index #{right_i} #{raw_leaderboard}"

      left = (raw_leaderboard.fetch left_i, nil)

      if left
        left = left.to_s
      end

      right = (raw_leaderboard.fetch right_i, nil)

      if right
        right = right.to_s
      end

      { left, right }
    else
      { nil, nil }
    end
  end

  def get_black_hole_players(public_key : String) : Tuple(Array(String), Array(String))
    count = 4
    player_index = get_leaderboard_index public_key
    raw_leaderboard = get_raw_leaderboard

    if player_index
      left_players = [] of String
      right_players = [] of String

      (1..count).each do |offset|
        left_i = player_index + offset
        if left_player = raw_leaderboard.fetch(left_i, nil)
          left_players << left_player.to_s
        end
      end

      (1..count).each do |offset|
        right_i = player_index - offset

        next if right_i < 0

        if right_player = raw_leaderboard.fetch(right_i, nil)
          if !right_players.includes?(right_player.to_s) && right_player.to_s != public_key
            right_players << right_player.to_s
          end
        end
      end

      #puts "Player Index #{player_index} Left Players #{left_players} Right Players #{right_players}"

      { left_players, right_players }
    else
      { [] of String, [] of String }
    end
  end

  # Formats units with commas or scientific notation based on value
  def format_units(value : BigFloat)
    if value < 1_000_000_000
      integer_part, decimal_part = value.to_s.split(".")
      formatted_integer = integer_part.reverse.chars.each_slice(3).map(&.join).join(",").reverse
      decimal_part ? "#{formatted_integer}.#{decimal_part}" : formatted_integer
    else
      format_in_scientific_notation(value)
    end
  end

  # Helper method to format numbers in scientific notation
  def format_in_scientific_notation(value : BigFloat) : String
    exponent = Math.log10(value).floor
    base = value / (10.0 ** exponent)
    "#{base.round(2)} x 10^#{exponent}"
  end

  def inc_time_units_ps (public_key : String, by : BigFloat)
    player_tu_ps = get_player_time_units_ps public_key
    set_player_time_units_ps public_key, (player_tu_ps + by)
  end

  def get_game_history
    lb = WWWR::R.lrange(Keys::GAME_WINNERS, 0, -1)
    lb.map { |x| Hash(String, String).from_json (x.to_s) }
  end

  def add_necrovoider(public_key : String)
    remove_necrovoider public_key
    WWWR::R.rpush Keys::NECROVOIDERS, public_key
  end

  def remove_necrovoider(public_key : String)
    WWWR::R.lrem Keys::NECROVOIDERS, 0, public_key
  end

  def get_necrovoiders
    WWWR::R.lrange(Keys::NECROVOIDERS, 0, -1)
  end

  def get_raw_leaderboard
    lb = WWWR::R.lrange(Keys::LEADERBOARD, 0, -1)

    get_necrovoiders.each do |pk|
      lb.push pk
    end

    lb.map { |x| x.to_s }.sort { |a, b| (get_player_time_units a.to_s) <=> (get_player_time_units b.to_s) }
  end

  def inc_time_units (public_key : String, by)
    player_tu = get_player_time_units public_key
    updated_tu = player_tu + by
    set_player_time_units public_key, updated_tu
  end

  def add_to_leaderboard (public_key : String)
    remove_from_leaderboard public_key
    WWWR::R.lpush Keys::LEADERBOARD, public_key
  end

  def remove_from_leaderboard (public_key : String)
    WWWR::R.lrem Keys::LEADERBOARD, 0, public_key
  end

  def get_key_value (public_key : String, key : String) : String
    global_vars = WWWR::R.hget Keys::GLOBAL_VARS, public_key
    global_vars ||= "{}"
    global_vars = JSON.parse global_vars
    begin
      global_vars[key].to_s
    rescue e
      ""
    end
  end

  def get_key_value_as_float (public_key : String , key : String, default : BigFloat) : BigFloat
    kv = get_key_value public_key, key
    if kv == ""
      kv = default
    end
    kv ||= default
    BigFloat.new kv
  end

  def get_key_value_as_float(public_key : String, key : String) : BigFloat
    get_key_value_as_float(public_key, key, BigFloat.new 0.0)
  end

  def get_key_value_as_int(public_key : String, key : String, default : BigInt) : BigInt
    BigInt.new get_key_value_as_float(public_key, key, BigFloat.new default)
  end

  def get_key_value_as_int(public_key : String, key : String) : BigInt
    BigInt.new get_key_value_as_float(public_key, key, BigFloat.new 0.0)
  end

  def set_timer (public_key : String, timer_key : String, seconds : Int64)
    set_key_value public_key, timer_key, (ts + seconds).to_s
  end

  def get_timer_seconds_left (public_key : String, timer_key : String) : Int32
    ((get_key_value_as_float public_key, timer_key) - ts).to_i
  end

  def get_timer_time_left (public_key : String, timer_key : String) : String
    seconds_left = get_timer_seconds_left public_key, timer_key
    format_time seconds_left
  end

  def is_timer_expired (public_key : String, timer_key : String) : Bool
    (get_timer_seconds_left public_key, timer_key) <= 0
  end

  def remove_powerup_if_timer_expired (public_key : String, timer_key : String, powerup_id : String)
    remove_powerup public_key, powerup_id if (is_timer_expired public_key, timer_key)
  end

  def set_key_value (public_key : String, key : String, value : String)
    gv = WWWR::R.hget Keys::GLOBAL_VARS, public_key
    gv ||= "{}"
    gv = Hash(String, String).from_json gv
    gv[key] = value
    WWWR::R.hset Keys::GLOBAL_VARS, public_key, gv.to_json
  end

  def sync_player (public_key : String)
    WWWR::Channels.each do |c|
      if c[2] == public_key && !c[1].closed?
        begin
          sync_data = Events.sync get_leaderboard, (get_data_for public_key), (get_serialized_powerups public_key), (get_time_left), (get_universe_change_log)
          c[1].send sync_data
        rescue e
          puts "Error during sync player #{public_key} #{e}"
        end
      end
    end
  end

  def sync
    WWWR::Channels.each do |c|
      spawn do
        channel = c[1]
        public_key = c[2]
        next if channel.closed?
        begin
          sync_data = Events.sync get_leaderboard, (get_data_for public_key), (get_serialized_powerups public_key), get_time_left, get_universe_change_log
          channel.send sync_data
        rescue e
          puts "Error during sync #{e}"
        end
      end
    end
  end

  def send_animation_event (public_key : String, animation : Animation, data)
    @animation_queue.push Events.animation public_key, animation, data
  end

  def broadcast_animation_event
    if @animation_queue.size == 0
      return
    end

    animation_batch = { "event" => "animation", "animations" => @animation_queue }.to_json
    WWWR::Channels.each do |c|
      spawn do
        channel = c[1]
        public_key = c[2]
        next if channel.closed?
        begin
          channel.send animation_batch
        rescue
        end
      end
    end

    @animation_queue.clear
  end

  def broadcast_online (public_key : String)
    add_to_leaderboard public_key
    puts "Broadcase online from #{public_key}"
    sync
  end

  def broadcast_offline (public_key : String)
    remove_from_leaderboard public_key
    puts "Broadcase offline from #{public_key}"
    sync
  end

  def get_actives (public_key : String) : Int32
    na = get_key_value(public_key, Keys::NUMBER_OF_ACTIVES).to_i?
    na ||= 0
    na
  end

  def add_active (public_key : String)
    set_key_value public_key, Keys::NUMBER_OF_ACTIVES, ((get_actives public_key) + 1).to_s
  end

  def add_powerup (public_key : String, powerup_id : String)
    remove_powerup public_key, powerup_id
    WWWR::R.rpush("powerups-#{public_key}", powerup_id)
  end

  def has_powerup (public_key : String, powerup_id : String) : Bool
    (get_player_powerups public_key).find { |x| x == powerup_id } != nil
  end

  def remove_powerup (public_key : String, powerup_id : String)
    WWWR::R.lrem("powerups-#{public_key}", 0, powerup_id)
  end

  def get_player_powerups (public_key : String)
    WWWR::R.lrange("powerups-#{public_key}", 0, -1)
  end

  def inc_powerup_stack (public_key : String, powerup_id : String)
    current_size = (get_key_value_as_float public_key, "stack-#{powerup_id}").to_i
    set_powerup_stack public_key, powerup_id, current_size + 1
  end

  def get_powerup_stack (public_key : String, powerup_id : String) : Int32
    stack_size = (get_key_value_as_float public_key, "stack-#{powerup_id}")
    stack_size.to_i
  end

  def set_powerup_stack (public_key : String, powerup_id : String, stack_size : Int32)
    set_key_value public_key, "stack-#{powerup_id}", stack_size.to_s
  end

  def get_player_frame_ups (public_key : String) : BigFloat
    result = WWWR::R.hget(Keys::PLAYER_FRAME_TUPS, public_key)
    if result == ""
      result = 0.0
    end
    result ||= 0.0;
    BigFloat.new result
  end

  def setup_new_waiter
    puts "Setting up new waiter."
    secret_token = Random.new.urlsafe_base64 64
    public_key = Random.new.urlsafe_base64

    p = WWWR::R.pipelined do |r|
      r.hset(Keys::PLAYER_TOKENS, secret_token, public_key)
      r.hset(Keys::PLAYER_TIME_UNITS, public_key, 0)
      r.hset(Keys::PLAYER_NAME, public_key, "Anonymous")
      r.hset(Keys::PLAYER_BG_COLOR, public_key, "#ffffff")
      r.hset(Keys::PLAYER_TEXT_COLOR, public_key, "#000000")
      r.hset(Keys::PLAYER_TIME_UNITS_PER_SECOND, public_key, @default_ups)
    end

    secret_token
  end

  def get_player_name (public_key : String) : String
    name = WWWR::R.hget(Keys::PLAYER_NAME, public_key)
    name ||= "Anonymous"
    name = name.to_s
    name
  end

  def get_data_for (public_key : String)
    time_units = Redis::Future.new
    player_name = Redis::Future.new
    player_bg_color = Redis::Future.new
    player_text_color = Redis::Future.new
    tps = Redis::Future.new
    metadata = Redis::Future.new
    player_can_alter_universe = Redis::Future.new

    WWWR::R.pipelined do |r|
      time_units = r.hget(Keys::PLAYER_TIME_UNITS, public_key)
      player_can_alter_universe = r.hget(Keys::PLAYER_CAN_ALTER_UNIVERSE, public_key)
      player_name = r.hget(Keys::PLAYER_NAME, public_key)
      player_bg_color = r.hget(Keys::PLAYER_BG_COLOR, public_key)
      player_text_color = r.hget(Keys::PLAYER_TEXT_COLOR, public_key)
      tps = r.hget(Keys::PLAYER_FRAME_TUPS, public_key)
      metadata = r.hget(Keys::GLOBAL_VARS, public_key)
    end

    powerups = (get_player_powerups public_key)
    powerup_classes = get_powerup_classes

    player_input_buttons = Array(Hash(String, String)).new
    powerup_popup_info = Hash(String, PopupInfo).new

    powerups.each do |pu|
      pc = powerup_classes.fetch pu.to_s, nil

      if !pc
        next
      end

      powerup_popup_info[pu.to_s] = pc.get_popup_info public_key

      if pc.is_input_powerup public_key
        player_input_buttons << ({ "name" => (pc.input_button_text public_key), "value" => pu.to_s })
      end
    end

    powerup_icons = powerups.map do |x|
      pc = powerup_classes[x]
      {
        "icon" => (pc.player_card_powerup_icon public_key),
        "powerup" => x,
        "name" => pc.get_name
      }
    end

    powerup_icons = powerup_icons.reject { |x| x["icon"] == "" }
    css_classes = powerups.map { |x| powerup_classes[x].player_card_powerup_active_css_class public_key }
    css_classes = css_classes.join " "

    return {
      Keys::PLAYER_POWERUP_POPUP_INFO => powerup_popup_info,
      Keys::PLAYER_NAME => player_name.value,
      Keys::PLAYER_BG_COLOR => player_bg_color.value,
      Keys::PLAYER_TEXT_COLOR => player_text_color.value,
      Keys::PLAYER_TIME_UNITS => time_units.value.to_s,
      Keys::PLAYER_TIME_UNITS_PER_SECOND => tps.value.to_s,
      Keys::PLAYER_INPUT_BUTTONS => player_input_buttons,
      Keys::PLAYER_PUBLIC_KEY => public_key,
      Keys::PLAYER_POWERUPS => powerups,
      Keys::PLAYER_METADATA => metadata.value,
      Keys::PLAYER_CARD_CSS_CLASSES => css_classes,
      Keys::PLAYER_POWERUP_ICONS => powerup_icons,
      Keys::PLAYER_CAN_ALTER_UNIVERSE => player_can_alter_universe.value.to_s != "",
    }
  end

  def set_bg_color_for (public_key : String, color)
    WWWR::R.hset(Keys::PLAYER_BG_COLOR, public_key, color)
  end

  def set_text_color_for (public_key : String, color)
    WWWR::R.hset(Keys::PLAYER_TEXT_COLOR, public_key, color)
  end

  def set_name_for (public_key : String, name)
    WWWR::R.hset(Keys::PLAYER_NAME, public_key, name)
  end

  def ts
    BigFloat.new(Time.utc.to_unix)
  end

  def frame_dt_ms
    now = Time.utc.to_unix_ms
    last_frame_time = WWWR::R.get(Keys::LAST_FRAME_TIME)
    last_frame_time ||= now
    now - last_frame_time.to_i64
  end

  def get_all_players
    all_player_tokens = WWWR::R.hgetall(Keys::PLAYER_TOKENS)
    all_players = all_player_tokens.values.uniq
    all_players
  end

  def reset_game
    active_players = get_raw_leaderboard
    save_game_winner(active_players)

    players = get_all_players

    players.each do |public_key|
      set_player_time_units public_key, BigFloat.new(0)
      set_player_time_units_ps public_key, BigFloat.new(@default_ups)

      WWWR::R.del("powerups-#{public_key}")

      powerup_classes = get_powerup_classes
      powerup_classes.each_key do |powerup_id|
        set_powerup_stack(public_key, powerup_id, 0)
      end

      current_globals = WWWR::R.hget(Keys::GLOBAL_VARS, public_key)
      if current_globals
        globals = Hash(String, String).from_json(current_globals)

        preserved_globals = Hash(String, String).new
        preserved_globals[Keys::NUMBER_OF_ACTIVES] = "0"

        WWWR::R.hset(Keys::GLOBAL_VARS, public_key, preserved_globals.to_json)
      end

      enable_unit_generation(public_key)
    end
    WWWR::R.set(Keys::TIME_LEFT, ONE_WEEK)

    @time_units_cache.clear
    @time_units_ps_cache.clear
    @last_buy.clear

    sync
  end

  def save_game_winner(players)
    winner = players.last

    if winner.empty?
      return
    end

    winner_data = {
      "name" => get_player_name(winner),
      "public_key" => winner,
      "units" => get_player_time_units(winner).to_s,
      "date" => Time.utc.to_s,
      "leaderboard" => players
    }.to_json

    WWWR::R.rpush(Keys::GAME_WINNERS, winner_data)
    WWWR::R.hset(Keys::PLAYER_CAN_ALTER_UNIVERSE, winner, "yes")
  end

  def update_for (public_key : String)
    data = get_data_for public_key
  end

  def secret_to_public (secret_key)
    pk = WWWR::R.hget Keys::PLAYER_TOKENS, secret_key
    pk == nil ? nil : pk.to_s
  end

  def get_player_time_units (public_key : String) : BigFloat
    result = @time_units_cache.fetch public_key, nil

    if result != nil
      result ||= BigFloat.new 0
      return result
    end

    result = WWWR::R.hget Keys::PLAYER_TIME_UNITS, public_key
    if result
      BigFloat.new result
    else
      BigFloat.new 0.0
    end
  end

  def set_player_time_units (public_key : String, to : BigFloat)
    @time_units_cache[public_key] = to
    WWWR::R.hset Keys::PLAYER_TIME_UNITS, public_key, to.to_s
  end

  def set_player_time_units_ps (public_key : String, to : BigFloat)
    @time_units_ps_cache[public_key] = to
    WWWR::R.hset Keys::PLAYER_TIME_UNITS_PER_SECOND, public_key, to.to_s
  end

  def get_player_time_units_ps (public_key : String) : BigFloat
    result = @time_units_ps_cache.fetch public_key, nil

    if result != nil
      result ||= BigFloat.new 0
      return result
    end

    result = WWWR::R.hget Keys::PLAYER_TIME_UNITS_PER_SECOND, public_key
    if result
      BigFloat.new result
    else
      BigFloat.new 0.0
    end
  end

  def get_public_key_from_ctx (ctx)
    secret_key = ctx.request.cookies[Keys::COOKIE].value
    public_key = secret_to_public secret_key
    public_key == nil ? nil : public_key.to_s
  end
end

def set_cookie(ctx, secret_key)
  cookie = HTTP::Cookie.new Keys::COOKIE, secret_key
  cookie.max_age = (10 * 364 * 24 * 60 * 60).seconds
  cookie.path = "/"

  ctx.request.cookies <<  cookie
  ctx.response.cookies << cookie
end

game = Game.new
game.spawn_loop

before_all do |ctx|
  begin
    secret_key = ctx.request.cookies[Keys::COOKIE].value

    if !(game.secret_to_public secret_key)
      secret_key = game.setup_new_waiter
    end

  rescue
    secret_key = game.setup_new_waiter
  end

  puts "Setup new waiter"
  set_cookie(ctx, secret_key)
end

post "/login" do |ctx|
  key = ctx.params.body["key"].as String
  if key
    lookup = game.secret_to_public key
    if lookup
      set_cookie ctx, key
      key
    else
      "Error"
    end
  else
    "Error"
  end
end

get "/history" do |ctx|
  game.get_game_history.to_json
end

get "/altercosmos" do |ctx|
  ctx.response.headers["Content-Type"] = "application/json"
  public_key = game.get_public_key_from_ctx ctx
  if !public_key
    ctx.response.status_code = 401
    { "error" => "invalid key" }.to_json
  else
    data = game.get_data_for public_key
    if data[Keys::PLAYER_CAN_ALTER_UNIVERSE] == true
      game.get_alteration_options.to_json
    else
      ctx.response.status_code = 401
      { "error" => "You cannot alter the cosmos." }.to_json
    end
  end
end

post "/altercosmos" do |ctx|
  public_key = game.get_public_key_from_ctx ctx
  if !public_key
    ctx.response.status_code = 401
    "Error"
  else
    data = game.get_data_for public_key
    if data[Keys::PLAYER_CAN_ALTER_UNIVERSE] == true
      alteration_id = ctx.params.body["alteration_id"].as String
      increase = ctx.params.body["increase"].as String == "yes"

      puts "#{alteration_id} #{increase}"

      alterations = game.get_alteration_options[alteration_id]

      min = alterations["min"].to_f64
      max = alterations["max"].to_f64
      alteration_name = alterations["name"]
      current_value = alterations["current_value"].to_f64
      inc = alterations["increment"].to_f64

      if increase
        new_value = current_value + inc
      else
        new_value = current_value - inc
      end

      if new_value >= min && new_value <= max
        WWWR::R.hdel Keys::PLAYER_CAN_ALTER_UNIVERSE, public_key
        if increase
          alteration_text = "#{alteration_name} increased by #{inc} to #{new_value}"
        else
          alteration_text = "#{alteration_name} decreased by #{inc} to #{new_value}"
        end
        game.log_universe_change public_key, alteration_text
        WWWR::R.set alteration_id, new_value
        game.set_alterations

        WWWR::Channels.each do |x|
          game.send_animation_event x[2], Animation::NUMBER_FLOAT, { "value" => alteration_text, "color" => "#FFFFFF", "steps" => 1000 }
        end

        game.sync
        "You have altered the universe."
      else
        ctx.response.status_code = 400
        "That value is invalid."
      end
    else
      ctx.response.status_code = 401
      "Error"
    end
  end
end

get "/" do |ctx|
  public_key = game.get_public_key_from_ctx ctx

  if !public_key
    "Error."
  else
    templates.render "index.html", ({
      "secret" => secret_key = ctx.request.cookies[Keys::COOKIE].value
    })
  end
end

post "/name" do |ctx|
  public_key = game.get_public_key_from_ctx ctx
  name = ctx.params.body["name"].as String
  if name && public_key
    game.set_name_for public_key, name
    #game.sync
  end
end

post "/buy" do |ctx|
  public_key = game.get_public_key_from_ctx ctx
  name = ctx.params.body["powerup"]

  if !public_key
    next
  end

  if !game.can_buy public_key
    puts "Rate limited buy of #{name} on #{public_key} #{game.get_player_name public_key}"
    next "Chill."
  end

  player_name = game.get_player_name public_key

  powerups = game.get_powerup_classes

  puts "#{player_name} (#{public_key}) purchased #{name}"

  if !(powerups.fetch name, nil)
    "That powerup does not exist."
  else
    if public_key
      resp = powerups[name].buy_action public_key
      # game.sync
      resp
    end
  end
end

post "/use" do |ctx|
  public_key = game.get_public_key_from_ctx ctx

  powerup = ctx.params.body["powerup"]
  on_player_key = ctx.params.body["on_player_key"]

  if !public_key || !on_player_key
    next
  end

  player_name = game.get_player_name public_key
  on_player_name = game.get_player_name on_player_key

  puts "#{player_name} (#{public_key}) used #{powerup} on #{on_player_name} (#{on_player_key})"

  pu_classes = game.get_powerup_classes
  pu_class = pu_classes.fetch powerup, nil

  if pu_class
    activates = pu_class.input_activates public_key
    puts "Powerup will activate #{activates}"
    pu_classes[activates].buy_action on_player_key
    game.set_key_value on_player_key, "#{activates}_afflicted_by", public_key
    game.remove_powerup public_key, powerup
  end
end

post "/color" do |ctx|
  public_key = game.get_public_key_from_ctx ctx

  bg_color = ctx.params.body.fetch "bg", ""
  text_color = ctx.params.body.fetch "text", ""

  regex = /\#[0-9a-f]{6}/

  if public_key
    if bg_color && regex.match bg_color
      game.set_bg_color_for public_key, bg_color
      #game.sync
    elsif text_color && regex.match text_color
      game.set_text_color_for public_key, text_color
      #game.sync
    end
  end
end

ws "/ws" do |socket, context|
  secret_key = context.request.cookies["token"].value
  public_key = game.secret_to_public secret_key

  if !public_key
    socket.close
    next
  end

  channel_key = Random.new.hex

  events = Channel(ChannelValueType).new

  spawn do
    loop do
      if events.closed?
        break
      end

      select
      when event_data = events.receive?
        if event_data
          socket.send event_data
        end
      else
      end

      Fiber.yield
    end
  end

  if public_key
    puts "#{secret_key} connected."
    WWWR::Channels.add ({ channel_key, events, public_key })
    game.broadcast_online public_key
  end

  socket.on_message do |msg|
    if public_key && !WWWR::Channels.find { |v| v[0] == channel_key }
      WWWR::Channels.add ({ channel_key, events, public_key })
      game.broadcast_online public_key
    end

    game.sync_player public_key
  end

  socket.on_close do
    puts "Socket closed"
    WWWR::Channels.delete ({ channel_key, events, public_key })
    events.close

    if !WWWR::Channels.find { |v| v[2] == public_key }
      game.broadcast_offline public_key
    end
  end
end

Kemal.run port: 8082
