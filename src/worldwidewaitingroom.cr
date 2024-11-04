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
require "./templates"
require "./powerups/schrodinger"
require "./powerups/cosmic_breakthrough"


alias Secret = String
alias Public = String
alias ChannelValueType = String

templates = Templates.new

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
      "event" => "animation",
      "player_public_key" => public_key,
      "animation" => animation.to_s,
      "data" => data
    }.to_json
  end

  def self.sync (leaderboard, player_data, powerups, time_left) : String
    {
      "event" => "sync",
      "leaderboard" => leaderboard,
      "time_left" => time_left,
      "player" => player_data,
      "powerups" => powerups
    }.to_json
  end
end

module Keys
  PLAYER_POWERUP_ICONS = "player_powerup_icons"
  PLAYER_CARD_CSS_CLASSES = "player_card_css_classes"
  NUMBER_OF_ACTIVES = "number_of_actives_purchased_ever"
  UNIT_GEN_DISABLED = "unit_gen_disabled"
  TIME_LEFT = "time_left"
  COOKIE = "token"
  GLOBAL_VARS = "global_vars"
  LAST_FRAME_TIME = "frame_time"
  LEADERBOARD = "online-leaderboard"
  PLAYER_PUBLIC_KEY = "public_key"
  PLAYER_POWERUPS = "powerups"
  PLAYER_METADATA = "metadata"
  PLAYER_TOKENS = "tokens"
  PLAYER_TIME_UNITS = "time_units"

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

    multiplier = BigFloat.new (dt / 1000.0)

    WWWR::R.incrby Keys::TIME_LEFT, -1
    get_time_left

    get_leaderboard.each do |player_data|
      player_public_key = player_data["public_key"].to_s

      set_player_time_units_ps player_public_key, BigFloat.new @default_ups
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

    if @sync_next_frame
      sync
      @sync_next_frame = false
    end

    update_frame_time
  end

  def get_powerup_classes
    {
      PowerupBootStrap.get_powerup_id => PowerupBootStrap.new(self),
      PowerupTimeWarp.get_powerup_id => PowerupTimeWarp.new(self),
      PowerupOverCharge.get_powerup_id => PowerupOverCharge.new(self),
      PowerupHarvest.get_powerup_id => PowerupHarvest.new(self),
      PowerupUnitMultiplier.get_powerup_id => PowerupUnitMultiplier.new(self),
      PowerupParasite.get_powerup_id => PowerupParasite.new(self),
      PowerupCompoundInterest.get_powerup_id => PowerupCompoundInterest.new(self),
      PowerupSynergyMatrix.get_powerup_id => PowerupSynergyMatrix.new(self),
      PowerupSignalJammer.get_powerup_id => PowerupSignalJammer.new(self),
      PowerupForceField.get_powerup_id => PowerupForceField.new(self),
      PowerupBreach.get_powerup_id => PowerupBreach.new(self),
      AfflictPowerupSignalJammer.get_powerup_id => AfflictPowerupSignalJammer.new(self),
      AfflictPowerupBreach.get_powerup_id => AfflictPowerupBreach.new(self),
      PowerupAutomationUpgrade.get_powerup_id => PowerupAutomationUpgrade.new(self),
      PowerupSchrodinger.get_powerup_id => PowerupSchrodinger.new(self),
      PowerupCosmicBreak.get_powerup_id => PowerupCosmicBreak.new(self),
    }
  end

  def get_time_left
    tl = WWWR::R.get Keys::TIME_LEFT
    if !tl || tl.to_i <= 0
      WWWR::R.set Keys::TIME_LEFT, 604800
      return 604800
    else
      return tl.to_i
    end
  end

  def get_serialized_powerups (public_key)
    powerups = [] of Hash(String, String | Bool | Int32)
    player_powerups = get_player_powerups public_key

    get_powerup_classes.each do |key, value|
      if value.is_afflication_powerup (public_key)
        next
      end

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
        powerup_class.action public_key, dt
      end
    end

    powerup_classes.each_value do |pc|
      if pc.is_achievement_powerup public_key
        pc.action public_key, dt
      end
    end
  end

  def do_powerup_cleanup (public_key : String)
    powerup_classes = get_powerup_classes
    (get_player_powerups public_key).each do |powerup_name|
      powerup_class = powerup_classes.fetch powerup_name, nil
      if powerup_class
        powerup_class.cleanup public_key
      end
    end

    powerup_classes.each_value do |pc|
      if pc.is_achievement_powerup public_key
        pc.cleanup public_key
      end
    end
  end

  def update_frame_time
    WWWR::R.set(Keys::LAST_FRAME_TIME, Time.utc.to_unix_ms)
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

  def inc_time_units_ps (public_key : String, by : BigFloat)
    player_tu_ps = get_player_time_units_ps public_key
    set_player_time_units_ps public_key, (player_tu_ps + by)
  end

  def get_raw_leaderboard
    lb = WWWR::R.lrange(Keys::LEADERBOARD, 0, -1)
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

  def get_key_value_as_float (public_key : String , key : String) : BigFloat
    kv = get_key_value public_key, key
    if kv == ""
      kv = 0.0
    end
    kv ||= 0.0
    BigFloat.new kv
  end

  def set_timer (public_key : String, timer_key : String, seconds : Int64)
    set_key_value public_key, timer_key, (ts + seconds).to_s
  end

  def get_timer_seconds_left (public_key : String, timer_key : String) : Int32
    ((get_key_value_as_float public_key, timer_key) - ts).to_i
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
          sync_data = Events.sync get_leaderboard, (get_data_for public_key), (get_serialized_powerups public_key), (get_time_left)
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
          sync_data = Events.sync get_leaderboard, (get_data_for public_key), (get_serialized_powerups public_key), get_time_left
          channel.send sync_data
        rescue e
          puts "Error during sync #{e}"
        end
      end
    end
  end

  def send_animation_event (public_key : String, animation : Animation, data)
    animation = Events.animation public_key, animation, data
    WWWR::Channels.each do |c|
      spawn do
        channel = c[1]
        public_key = c[2]
        next if channel.closed?
        begin
          channel.send animation
        rescue
        end
      end
    end
  end

  def defer_sync
    @sync_next_frame = true
  end

  def broadcast_animation_event (public_key : String)
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
    secret_token = Random.new.hex
    public_key = Random.new.hex

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

    WWWR::R.pipelined do |r|
      time_units = r.hget(Keys::PLAYER_TIME_UNITS, public_key)
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
    Time.utc.to_unix
  end

  def frame_dt_ms
    now = Time.utc.to_unix_ms
    last_frame_time = WWWR::R.get(Keys::LAST_FRAME_TIME)
    last_frame_time ||= now
    now - last_frame_time.to_i64
  end

  def reset_game

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
  cookie = HTTP::Cookie.new Keys::COOKIE, secret_key
  cookie.max_age = (10 * 364 * 24 * 60 * 60).seconds
  cookie.path = "/"

  ctx.request.cookies <<  cookie
  ctx.response.cookies << cookie
end

get "/" do |ctx|
  public_key = game.get_public_key_from_ctx ctx

  if !public_key
    "Error."
  else
    templates.render "index.html", ({ "data" => (game.get_data_for public_key), "time_left" => game.get_time_left })
  end
end

post "/name" do |ctx|
  public_key = game.get_public_key_from_ctx ctx
  name = ctx.params.body["name"].as String
  if name && public_key
    game.set_name_for public_key, name
    game.sync
  end
end

post "/buy" do |ctx|
  public_key = game.get_public_key_from_ctx ctx
  name = ctx.params.body["powerup"]

  if !public_key
    next
  end

  player_name = game.get_player_name public_key

  powerups = game.get_powerup_classes

  puts "#{player_name} (#{public_key}) purchased #{name}"

  if !(powerups.fetch name, nil)
    "That powerup does not exist."
  else
    if public_key
      resp = powerups[name].buy_action public_key
      game.sync
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
      game.sync
    elsif text_color && regex.match text_color
      game.set_text_color_for public_key, text_color
      game.sync
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

  socket.on_message do
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
    game.broadcast_offline public_key
  end
end

Kemal.run port: 8082
