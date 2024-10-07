require "kemal"
require "random"
require "json"
require "redis"
require "./templates"

alias Secret = String
alias Public = String

templates = Templates.new

module WWWR
  R = Redis::PooledClient.new
  Online = Hash(Public, Secret).new
end

def update
  puts "Game loop tick... Num sockets #{WWWR::Online.size}"

  tick_global_timer

  get_leaderboard.each do |data|
    pub_key = data["user"]
    if WWWR::Online.has_key? pub_key
      add_time_to pub_key, 1
    else
      inc_key("offline_time", pub_key)
    end

    if (get_int_key "rate_limit", pub_key) > 0
      dec_key "rate_limit", pub_key
    end

    update_leaderboard_for pub_key
  end
end


# Global timer
spawn do
  loop do
    begin
      update
    rescue ex
      puts "Exception in main loop #{ex}"
    end

    sleep 1
  end
end

def tick_global_timer
  gtl = get_global_time_left
  WWWR::R.incrby "global_time", -1
  if gtl <= 0
    reset_game
  end
end

def reset_game
  WWWR::R.set "global_time", 604800

  leaderboard = get_leaderboard
  WWWR::R.lpush "leaderboards", leaderboard.to_json

  time_waited_keys = WWWR::R.hkeys("time_waited")

  time_waited_keys.each do |key|
    WWWR::R.hset("time_waited", key, 0)
  end
end

def get_global_time_left
  global_time = WWWR::R.get "global_time"

  if global_time == nil
    WWWR::R.set "global_time", 604800
  end

  global_time ||= 604800
  global_time.to_i
end

def add_time_to (pubkey, seconds)
  WWWR::R.hincrby("time_waited", pubkey, seconds)
end

def remove_time_from (pubkey, seconds)
  add_time_to pubkey, -seconds
end

def update_leaderboard_for (public_key)
  WWWR::R.zadd("leaderboard", (get_wait_time public_key), public_key)
end

def get_data_for (pub_key)
  mdata = WWWR::R.hget "data", pub_key

  if !mdata
    return nil
  end

  begin
    parsed = Hash(String, String | Int64 | Bool).from_json(mdata)
  rescue
    return nil
  end

  takeable_time = (get_takeable_time pub_key)

  parsed["time_waited"] = build_time_left_string (get_wait_time pub_key)
  parsed["offline_time"] = build_time_left_string (get_offline_time pub_key)
  parsed["has_time_to_take"] = takeable_time > 0
  parsed["takeable_time"] = build_time_left_string takeable_time
  parsed["user"] = "#{pub_key}"
  parsed["is_online"] = (WWWR::Online.has_key? pub_key)
  parsed["rate_limit_time_left"] = build_time_left_string (get_rate_limit pub_key)

  parsed
end

def set_data_for (pub_key, data : String)
  WWWR::R.hset "data", pub_key, data
end

def get_leaderboard_place (pub_key)
  leaderboard = WWWR::R.zrange("leaderboard", 0, -1).reverse

  place = leaderboard.index pub_key
  place ||= 10000000
  place + 1
end

def get_leaderboard
  leaderboard = WWWR::R.zrange("leaderboard", 0, -1).reverse
  data = [] of Hash(String, String | Int64 | Bool)

  leaderboard.each do |member|
    mdat = get_data_for member
    if mdat
      data << mdat
    end
  end

  data
end

def append_time_to_string (str, value, unit)
  if value > 0
    str = "#{str}#{value} #{unit}"
    if value > 1
      str = "#{str}s"
    end
    str = "#{str} "
  end
  str
end

def build_time_left_string (seconds)
    days_left =    seconds // 60 // 60 // 24
    hours_left =   seconds // 60 // 60 % 24
    minutes_left = seconds // 60 % 60
    seconds_left = seconds % 60

    output = ""

    output = append_time_to_string output, days_left, "day"
    output = append_time_to_string output, hours_left, "hour"
    output = append_time_to_string output, minutes_left, "minute"
    output = append_time_to_string output, seconds_left, "second"

    output
end

def setup_new_waiter
  puts "Setting up new waiter."
  secret_token = Random.new.hex
  public_token = Random.new.hex

  WWWR::R.hset("tokens", secret_token, public_token)
  WWWR::R.hset("time_waited", public_token, 0)
  WWWR::R.hset("data", public_token, { "name" => "Anonymous", "color" => "#ffffff", "compressed" => false }.to_json)

  secret_token
end

def secret_to_public (secret_key)
  WWWR::R.hget "tokens", secret_key
end

def get_int_key (hmap, key) : Int64
  value = WWWR::R.hget(hmap, key)
  value ||= 0
  Int64.new value.to_i
end

def inc_key (hmap, key)
  WWWR::R.hincrby hmap, key, 1
end

def dec_key (hmap, key)
  WWWR::R.hincrby hmap, key, -1
end

def get_offline_time (pub_key)
  get_int_key "offline_time", pub_key
end

def get_wait_time (public_key)
  get_int_key "time_waited", public_key
end

def get_rate_limit (pub_key)
  get_int_key "rate_limit", pub_key
end

def can_take (pub_key) : Bool
  if !pub_key
    return false
  end

  can_take = get_int_key "rate_limit", pub_key

  return can_take <= 0
end

def rate_limit_take (pub_key)
  if !pub_key
    return
  end

  WWWR::R.hset "rate_limit", pub_key, 60 * 60 * 24
end

def get_takeable_time (pub_key)
  Math.min (get_offline_time pub_key), (get_wait_time pub_key)
end

post "/transfer" do |ctx|
  secret_key = ctx.request.cookies["token"].value
  public_key = secret_to_public secret_key

  waiter = ctx.params.body["waiter"].as String
  action = ctx.params.body["action"].as String

  puts "#{waiter} #{action} #{public_key}"

  amount = get_takeable_time public_key

  puts "#{public_key} #{waiter}"
  is_waiter_online = WWWR::Online.has_key? waiter

  puts "WAITER ONLINE #{is_waiter_online}"

  if is_waiter_online
    puts "#{public_key} tried to take from #{waiter} but he was online."
    next "Can't take from an online player."
  end

  if public_key != waiter && !is_waiter_online
     if action == "take"
      if !(can_take public_key)
        puts "#{public_key} was rate limited."
        next "No"
      end

      waiter_wait_time = (get_wait_time waiter)

      puts "#{waiter_wait_time} #{amount}"

      if waiter_wait_time >= amount
        puts "#{public_key} took offline time #{waiter_wait_time} from #{waiter}"
        remove_time_from waiter, amount
        add_time_to public_key, amount
        rate_limit_take public_key
      end
    end
  end
end

before_all do |ctx|
  begin
    secret_key = ctx.request.cookies["token"].value

    if !(secret_to_public secret_key)
      secret_key = setup_new_waiter
    end

  rescue
    secret_key = setup_new_waiter
  end

  puts "Setup new waiter"
  ctx.request.cookies["token"] = secret_key
  ctx.response.cookies["token"] = secret_key
end

def get_pub_key_from_ctx (ctx)
  secret_key = ctx.request.cookies["token"].value
  public_key = secret_to_public secret_key
  public_key
end

get "/" do |ctx|
  public_key = get_pub_key_from_ctx ctx
  templates.render "index.html", get_data_for public_key
end

post "/compressed" do |ctx|
  public_key = get_pub_key_from_ctx ctx
  compressed = ctx.params.body["compressed"].as String
  data = get_data_for public_key
  if data
    data["compressed"] = compressed == "yes"
    set_data_for public_key, data.to_json
  end

  templates.render "compress-button.html", { "compressed" => compressed == "yes" }
end

get "/compressed" do |ctx|
  public_key = get_pub_key_from_ctx ctx
  data = get_data_for public_key

  if data
    is_compressed = data.fetch "compressed", false
  else
    is_compressed = false
  end

  templates.render "compress-button.html", { "compressed" => is_compressed }
end

post "/name" do |ctx|
  public_key = get_pub_key_from_ctx ctx
  name = ctx.params.body["name"].as String
  data = get_data_for public_key
  if data
    data["name"] = name
    set_data_for public_key, data.to_json
  end
end

post "/color" do |ctx|
  public_key = get_pub_key_from_ctx ctx
  color = ctx.params.body["color"].as String
  data = get_data_for public_key
  if data && /\#[0-9a-f]{6}/.match color
    data["color"] = color
    set_data_for public_key, data.to_json
  end
end

ws "/ws" do |socket, context|
  secret_key = context.request.cookies["token"].value
  pub_key = secret_to_public secret_key

  if pub_key
    puts "#{secret_key} connected."
    update_leaderboard_for pub_key
    WWWR::R.hdel("offline_time", pub_key)
    WWWR::Online[pub_key] = secret_key
  end

  socket.on_message do
    leaderboard = get_leaderboard
    global_time = build_time_left_string (get_global_time_left)

    data = get_data_for pub_key

    if !data
      puts "No data from Redis in render loop.... skipping."
      next
    end

    data["place"] = get_leaderboard_place pub_key

    html = templates.render "live-html.html", {
      "leaderboard" => leaderboard,
      "this_waiter" => pub_key,
      "is_online" => (WWWR::Online.has_key? pub_key),
      "data" => data,
      "can_take" => (can_take pub_key),
      "time_left" => global_time
    }

    if socket.closed?
      puts "Socket is closed. Ignoring"
      WWWR::Online.delete pub_key
      next
    end

    begin
      socket.send html
    rescue
      puts "Could not send to socket. Ignoring."
      WWWR::Online.delete pub_key
    end
  end

  socket.on_close do
    puts "Socket closed"
    WWWR::Online.delete pub_key
  end
end

Kemal.run port: 8082
