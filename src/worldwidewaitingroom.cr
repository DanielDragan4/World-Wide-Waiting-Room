require "kemal"
require "random"
require "json"
require "redis"
require "./templates"

alias Secret = String
alias Public = String

templates = Templates.new
redis = Redis::PooledClient.new
sockets = Hash(HTTP::WebSocket, Tuple(Secret, Public)).new

def update (tick, sockets, redis, templates)
  seen = Set(Secret).new
  puts "Game loop tick... Num sockets #{sockets.size}"

  if tick
    tick_global_timer redis
  end

  leaderboard = get_leaderboard redis
  global_time = build_time_left_string (get_global_time_left redis)

  sockets.each do |socket, pub_priv|
    priv_key, pub_key = pub_priv

    puts "DEBUG: Processing #{pub_key}"
    if tick
      puts "DEBUG: Ticking"
      if !seen.includes? priv_key
        seen.add priv_key
        add_time_to redis, pub_key, 1
        update_leaderboard_for redis, pub_key
      end
      puts "DEBUG: Ticking done"
    end

    puts "DEBUG: Get data from Redis..."
    data = get_data_for redis, pub_key
    puts "DEBUG: Get data from redis done."

    if !data
      puts "No data from Redis in render loop.... skipping."
      next
    end

    puts "DEBUG: Get leader board..."
    data["place"] = get_leaderboard_place redis, pub_key
    puts "DEBUG: Get leaderboard done."

    puts "DEBUG: Rendering HTML..."
    html = templates.render "live-html.html", { "leaderboard" => leaderboard, "this_waiter" => pub_key, "data" => data, "can_take" => (can_take redis, pub_key), "time_left" => global_time }
    puts "DEBUG: Rendering HTML Done."

    if socket.closed?
      puts "Socket is closed. Ignoring"
      sockets.delete pub_key
      remove_from_leaderboard redis, pub_key
      next
    end

    puts "DEBUG: Sending socket...."
    begin
      safe_socket_sent socket, html
    rescue
      puts "Could not send to socket. Ignoring."
      sockets.delete pub_key
      remove_from_leaderboard redis, pub_key
    end
    puts "DEBUG: Sending socket done."
  end
end

# Global timer
spawn do
  redis.del("leaderboard")
  tick = true
  loop do
    begin
      update tick, sockets, redis, templates
    rescue ex
      puts "Exception in main loop #{ex}"
    end

    # tick = !tick

    #sleep 1 / 2
  end
end

def tick_global_timer (r)
  gtl = get_global_time_left r
  r.incrby "global_time", -1
  if gtl <= 0
    reset_game r
  end
end

def reset_game (r)
  r.set "global_time", 604800

  leaderboard = get_leaderboard r
  r.lpush "leaderboards", leaderboard.to_json

  time_waited_keys = r.hkeys("time_waited")

  time_waited_keys.each do |key|
    r.hset("time_waited", key, 0)
  end
end

def get_global_time_left (r)
  global_time = r.get "global_time"

  if global_time == nil
    r.set "global_time", 604800
  end

  global_time ||= 604800
  global_time.to_i
end

def add_time_to (r, pubkey, seconds)
  r.hincrby("time_waited", pubkey, seconds)
end

def remove_time_from (r, pubkey, seconds)
  add_time_to r, pubkey, -seconds
end

def update_leaderboard_for (r, public_key)
  r.zadd("leaderboard", (get_wait_time r, public_key), public_key)
end

def get_data_for (r, pub_key)
  mdata = r.hget "data", pub_key

  if !mdata
    return nil
  end

  begin
    parsed = Hash(String, String | Int64 | Bool).from_json(mdata)
  rescue
    return nil
  end

  parsed["time_waited"] = build_time_left_string (get_wait_time r, pub_key)
  parsed["user"] = "#{pub_key}"

  parsed
end

def set_data_for (r, pub_key, data : String)
  r.hset "data", pub_key, data
end

def get_leaderboard_place (r, pub_key)
  leaderboard = r.zrange("leaderboard", 0, -1).reverse

  place = leaderboard.index pub_key
  place ||= 10000000
  place + 1
end

def get_leaderboard (r)
  leaderboard = r.zrange("leaderboard", 0, -1).reverse
  data = [] of Hash(String, String | Int64 | Bool)

  leaderboard.each do |member|
    mdat = get_data_for r, member
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

def setup_new_waiter (r)
  puts "Setting up new waiter."
  secret_token = Random.new.hex
  public_token = Random.new.hex

  r.hset("tokens", secret_token, public_token)
  r.hset("time_waited", public_token, 0)
  r.hset("data", public_token, { "name" => "Anonymous", "color" => "#ffffff", "compressed" => false }.to_json)

  secret_token
end

def secret_to_public (r, secret_key)
  return r.hget "tokens", secret_key
end

def get_wait_time (r, public_key) : Int64
  time_waited = r.hget("time_waited", public_key)
  time_waited ||= 0
  Int64.new time_waited.to_i
end

def can_take (r, pub_key) : Bool
  if !pub_key
    return false
  end

  can_take = r.get ("exp" + pub_key)

  return can_take == nil
end

def rate_limit_take (r, pub_key)
  if !pub_key
    return
  end

  r.set ("exp" + pub_key), "yes"
  r.expire ("exp" + pub_key), 2
end

post "/transfer" do |ctx|
  secret_key = ctx.request.cookies["token"].value
  public_key = secret_to_public redis, secret_key

  waiter = ctx.params.body["waiter"].as String
  action = ctx.params.body["action"].as String

  puts "#{waiter} #{action} #{public_key}"

  amount = 10

  if public_key != waiter
    if action == "give"
      if (get_wait_time redis, public_key) >= amount
        puts "Giving 10m to #{waiter} from #{public_key}"
        add_time_to redis, waiter, amount
        remove_time_from redis, public_key, amount
      end
    elsif action == "take"
      if !(can_take redis, public_key)
        puts "#{public_key} was rate limited."
        next "No"
      end

      rate_limit_take redis, public_key
      if (get_wait_time redis, waiter) >= amount
        puts "Taking 10m from #{waiter} and giving to #{public_key}"
        remove_time_from redis, waiter, amount
        add_time_to redis, public_key, amount
      end
    end
  end
end

before_all do |ctx|
  begin
    secret_key = ctx.request.cookies["token"].value

    if !(secret_to_public redis, secret_key)
      secret_key = setup_new_waiter redis
    end

  rescue
    secret_key = setup_new_waiter redis
  end

  puts "Setup new waiter"
  ctx.request.cookies["token"] = secret_key
  ctx.response.cookies["token"] = secret_key
end

def get_pub_key_from_ctx (r, ctx)
  secret_key = ctx.request.cookies["token"].value
  public_key = secret_to_public r, secret_key
  public_key
end

get "/" do |ctx|
  public_key = get_pub_key_from_ctx redis, ctx
  templates.render "index.html", get_data_for redis, public_key
end

post "/compressed" do |ctx|
  public_key = get_pub_key_from_ctx redis, ctx
  compressed = ctx.params.body["compressed"].as String
  data = get_data_for redis, public_key
  if data
    data["compressed"] = compressed == "yes"
    set_data_for redis, public_key, data.to_json
  end

  templates.render "compress-button.html", { "compressed" => compressed == "yes" }
end

get "/compressed" do |ctx|
  public_key = get_pub_key_from_ctx redis, ctx
  data = get_data_for redis, public_key

  if data
    is_compressed = data.fetch "compressed", false
  else
    is_compressed = false
  end

  templates.render "compress-button.html", { "compressed" => is_compressed }
end

def remove_from_leaderboard (r, pub_key)
  puts "Removed #{pub_key} from leaderboard"
  r.zrem("leaderboard", pub_key)
end

post "/name" do |ctx|
  public_key = get_pub_key_from_ctx redis, ctx
  name = ctx.params.body["name"].as String
  data = get_data_for redis, public_key
  if data
    data["name"] = name
    set_data_for redis, public_key, data.to_json
  end
end

post "/color" do |ctx|
  public_key = get_pub_key_from_ctx redis, ctx
  color = ctx.params.body["color"].as String
  data = get_data_for redis, public_key
  if data && /\#[0-9a-f]{6}/.match color
    data["color"] = color
    set_data_for redis, public_key, data.to_json
  end
end

ws "/ws" do |socket, context|
  secret_key = context.request.cookies["token"].value
  public_key = secret_to_public redis, secret_key

  if public_key
    puts "#{secret_key} connected."
    update_leaderboard_for redis, public_key
    sockets[socket] = ({ secret_key, public_key })
  end

  socket.on_close do
    puts "Socket closed"
    if public_key
      redis.zrem("leaderboard", public_key)
      sockets.delete socket
    end
  end
end

Kemal.run port: 8082
