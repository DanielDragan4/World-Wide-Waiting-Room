require "kemal"
require "random"
require "json"
require "redis"
require "base64"
require "./powerups"
require "./templates"

alias Secret = String
alias Public = String

templates = Templates.new

module WWWR
  R = Redis::PooledClient.new
  Online = Hash(Public, Secret).new
  Channels = Hash(String, Channel(Nil)).new
end

module Events
  SYNC = "sync"
  LOGIN = "login"
  ORDER_CHANGED = "order_change"
  LOGOUT = "logout"
  PLAYER_UPDATE = "player_update"

  def self.sync (leaderboard, player_data, powerups, time_left)
    {
      "event" => Events::SYNC,
      "leaderboard" => leaderboard,
      "time_left" => time_left,
      "player" => player_data,
      "powerups" => powerups
    }
  end
end

module Keys
  TIME_LEFT = "time_left"
  COOKIE = "token"
  LAST_FRAME_TIME = "frame_time"
  LEADERBOARD = "online-leaderboard"
  PLAYER_TOKENS = "tokens"
  PLAYER_TIME_UNITS = "time_units"
  PLAYER_TIME_UNITS_PER_SECOND = "time_units_per_second"
  PLAYER_NAME = "name"
  PLAYER_TEXT_COLOR = "bg_color"
  PLAYER_BG_COLOR = "text_color"
end

module Powerups
  DOUBLE_TIME = "double_time"
end

class Game
  @sync_next_frame = false

  def spawn_loop
    update_frame_time
    spawn do
      loop do
        tick
        sleep 1.second
      end
    end
  end

  def tick
    dt = frame_dt_ms
    puts "Last frame #{dt}ms"

    multiplier = dt / 1000.0

    WWWR::R.incrby Keys::TIME_LEFT, -1
    get_time_left

    get_leaderboard.each do |player_data|
      player_public_key = player_data["public_key"]

      do_powerup_actions player_public_key, dt

      player_tups = get_player_time_units_ps player_public_key
      inc_time_units player_public_key, player_tups * multiplier

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
      Powerups::DOUBLE_TIME => PowerupDoubleTime.new self
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
    powerups = [] of Hash(String, String | Float64 | Bool | Int32)
    player_powerups = get_player_powerups public_key

    get_powerup_classes.each do |key, value|
      powerups << {
        "id" => key,
        "name" => value.get_name,
        "description" => value.get_description,
        "price" => value.get_price,
        "is_stackable" => value.is_stackable,
        "is_available_for_purchase" => value.is_available_for_purchase,
        "max_stack_size" => value.max_stack_size,
        "currently_owns" => (player_powerups.includes? key),
        "current_stack_size" => (value.get_player_stack_size public_key),
      }
    end

    powerups
  end

  def do_powerup_actions (public_key, dt)
    powerup_classes = get_powerup_classes
    (get_player_powerups public_key).each do |powerup_name|
      powerup_class = powerup_classes.fetch powerup_name, nil
      if powerup_class
        powerup_class.action public_key, dt
      end
    end
  end

  def do_powerup_cleanup (public_key)
    powerup_classes = get_powerup_classes
    (get_player_powerups public_key).each do |powerup_name|
      powerup_class = powerup_classes.fetch powerup_name, nil
      if powerup_class
        powerup_class.cleanup public_key
      end
    end
  end

  def update_frame_time
    WWWR::R.set(Keys::LAST_FRAME_TIME, Time.utc.to_unix_ms)
  end

  def get_leaderboard
    leaderboard = WWWR::R.zrange(Keys::LEADERBOARD, 0, -1)
    leaderboard.map { |public_key| get_data_for public_key }
  end

  def inc_time_units (public_key, by)
    player_tu = get_player_time_units public_key
    updated_tu = player_tu + by

    WWWR::R.pipelined do |r|
      r.hset Keys::PLAYER_TIME_UNITS, public_key, updated_tu
      r.zadd Keys::LEADERBOARD, updated_tu, public_key
    end
  end

  def inc_time_units_ps (public_key, by)
    player_tu_ps = get_player_time_units_ps public_key
    set_player_time_units_ps (player_tu_ps + by)
  end

  def add_to_leaderboard (public_key)
    WWWR::R.zadd Keys::LEADERBOARD, (get_player_time_units public_key), public_key
  end

  def remove_from_leaderboard (public_key)
    WWWR::R.zrem Keys::LEADERBOARD, public_key
  end

  def get_key_value (public_key, key)
    WWWR::R.hget public_key, key
  end

  def set_key_value (public_key, key, value)
    WWWR::R.hset public_key, key, value
  end

  def sync
    WWWR::Channels.each_value do |c|
      spawn do
        next if c.closed?
        begin
          c.send nil
        rescue
        end
      end
    end
  end

  def defer_sync
    @sync_next_frame = true
  end

  def broadcast_online (public_key)
    add_to_leaderboard public_key
    puts "Broadcase online from #{public_key}"
    sync
  end

  def broadcast_offline (public_key)
    remove_from_leaderboard public_key
    puts "Broadcase offline from #{public_key}"
    sync
  end

  def add_powerup (public_key, powerup)
    WWWR::R.zadd("powerups-#{public_key}", 0, powerup)
  end

  def remove_powerup (public_key, powerup)
    WWWR::R.zrem("powerups-#{public_key}", powerup)
  end

  def get_player_powerups (public_key)
    WWWR::R.zrange("powerups-#{public_key}", 0, -1)
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
      r.hset(Keys::PLAYER_TIME_UNITS_PER_SECOND, public_key, 1)
    end

    secret_token
  end

  def get_data_for (public_key)
    time_units = Redis::Future.new
    player_name = Redis::Future.new
    player_bg_color = Redis::Future.new
    player_text_color = Redis::Future.new
    tps = Redis::Future.new

    WWWR::R.pipelined do |r|
      time_units = r.hget(Keys::PLAYER_TIME_UNITS, public_key)
      player_name = r.hget(Keys::PLAYER_NAME, public_key)
      player_bg_color = r.hget(Keys::PLAYER_BG_COLOR, public_key)
      player_text_color = r.hget(Keys::PLAYER_TEXT_COLOR, public_key)
      tps = r.hget(Keys::PLAYER_TIME_UNITS_PER_SECOND, public_key)
    end

    return {
      "name" => player_name.value,
      "bg_color" => player_bg_color.value,
      "text_color" => player_text_color.value,
      "time_units" => time_units.value.to_s.to_f64?,
      "time_units_per_second" => tps.value.to_s.to_f64?,
      "public_key" => public_key,
      "powerups" => get_player_powerups public_key
    }
  end

  def set_bg_color_for (public_key, color)
    WWWR::R.hset(Keys::PLAYER_BG_COLOR, public_key, color)
  end

  def set_text_color_for (public_key, color)
    WWWR::R.hset(Keys::PLAYER_TEXT_COLOR, public_key, color)
  end

  def set_name_for (public_key, name)
    WWWR::R.hset(Keys::PLAYER_NAME, public_key, name)
  end

  def frame_dt_ms
    now = Time.utc.to_unix_ms
    last_frame_time = WWWR::R.get(Keys::LAST_FRAME_TIME)
    last_frame_time ||= now
    now - last_frame_time.to_i64
  end

  def reset_game

  end

  def update_for (public_key)
    data = get_data_for public_key
  end

  def secret_to_public (secret_key)
    WWWR::R.hget Keys::PLAYER_TOKENS, secret_key
  end

  def get_player_time_units (public_key)
    result = WWWR::R.hget Keys::PLAYER_TIME_UNITS, public_key
    if result
      return result.to_f64
    else
      return Float64.new 0.0
    end
  end

  def set_player_time_units (public_key, to : Float64)
    WWWR::R.hset Keys::PLAYER_TIME_UNITS, public_key, to
  end

  def set_player_time_units_ps (public_key, to : Float64)
    WWWR::R.hset Keys::PLAYER_TIME_UNITS_PER_SECOND, public_key, to
  end

  def get_player_time_units_ps (public_key)
    result = WWWR::R.hget Keys::PLAYER_TIME_UNITS_PER_SECOND, public_key
    if result
      return result.to_f64
    else
      return Float64.new 0.0
    end
  end

  def get_public_key_from_ctx (ctx)
    secret_key = ctx.request.cookies[Keys::COOKIE].value
    public_key = secret_to_public secret_key
    public_key
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
  templates.render "index.html", ({ "data" => (game.get_data_for public_key), "time_left" => game.get_time_left })
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

  powerups = game.get_powerup_classes

  if !(powerups.fetch name, nil)
    "That powerup does not exist."
  else
    resp = powerups[name].buy_action public_key
    game.sync
    resp
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
  channel_key = Random.new.hex

  events = Channel(Nil).new

  spawn do
    loop do
      if events.closed?
        break
      end

      select
      when events.receive?
        sync_data = Events.sync game.get_leaderboard, (game.get_data_for public_key), (game.get_serialized_powerups public_key), (game.get_time_left)
        socket.send sync_data.to_json
      else
      end

      Fiber.yield
    end
  end

  if public_key
    puts "#{secret_key} connected."
    WWWR::Online[public_key] = secret_key
    WWWR::Channels[channel_key] = events
    game.broadcast_online public_key
  end

  socket.on_message do
    if public_key && !WWWR::Online.includes? public_key
      WWWR::Online[public_key] = secret_key
      WWWR::Channels[channel_key] = events
      game.broadcast_online public_key
    end

    events.send nil
  end

  socket.on_close do
    puts "Socket closed"
    WWWR::Online.delete public_key
    WWWR::Channels.delete channel_key
    events.close
    game.broadcast_offline public_key
  end
end

Kemal.run port: 8082
