require "kemal"
require "./templates"
require "./eventing"

templates = Templates.new
eventing = Eventing.new

# These represent the current rates of increase/decrease
# We use Atomics to prevent race conditions
# This number represents milliseconds

module Values
  SomeValue = Atomic(Int64).new 60000
end

# User timer stuff

def start_user_timer (eventing, socket_channel, firstSession)
  # Load in the last known time for the user here ...

  current_time_milliseconds : Int64 = 0

  #to check wether the current person previously was online and sets time to previous
  if !firstSession
    current_time_milliseconds = get_users_last_time()
  end

  spawn do
    loop do
      current_time_milliseconds += 1000
      eventing.emit({ :timer, current_time_milliseconds })
      sleep 1
      Fiber.yield
      break if socket_channel.closed?
    end
  end
end

# The timer Fiber

def load_last_known_time_left
  Int64.new 60 * 60 * 1000 # Some millisecond value. Not sure exactly where this will b3e coming from yet.
end

def get_users_last_time
  #time that the last user had kept somewhere
end

def get_rank
  #returns the players rank
end

def val_change(num_clicks)
  #returns the amount that will be added to time left
end

# def daily_inc_clicks(firstSession)
#   inc_clicks = 0
#   if !firstSession
#     # some way of getting the number of clicks from whatever db is used
#   end

#     inc_clicks += 1
#   time_left += val_change(inc_clicks)
# end

# def daily_dec_clicks(firstSession)
#   dec_clicks = 0
#   if !firstSession
#     # some way of getting the number of clicks from whatever db is used
#   end
#     inc_clicks += 1
#   time_left -= val_change(inc_clicks)
# end

spawn do
  time_left = load_last_known_time_left()
  loop do
    time_left -= 1
    eventing.emit({ :global_timer, time_left })
    sleep 1
    Fiber.yield
  end
end

# HTTP Route handing stuff.

post "/increase" do
  # This is where the global
  "Increase Timer"
  Values::SomeValue.add 1000
  eventing.emit({ :inc, Values::SomeValue.get })
end

post "/decrease" do
  "Decrease Timer"
  Values::SomeValue.sub 1000
  eventing.emit({ :dec, Values::SomeValue.get })
end

get "/" do
  templates.render "index.html"
end

ws "/ws" do |socket|
  puts "The socket opened"

  events = Channel(Event).new
  id = eventing.register_channel events

  socket_status = Channel(Nil).new

  socket.on_close do
    socket_status.close
    eventing.unregister_channel id
    eventing.emit({ :disconnected, Int64.new 0 })
    puts "The socket closed"
  end

  spawn do
    loop do
      value = Values::SomeValue.get

      select
      when event = events.receive
        name, value = event

        case name
        when :inc
          puts "Added #{value}"
          socket.send "<div id=\"number\">#{value}</div>"
        when :dec
          puts "Decremented #{value}"
          socket.send "<div id=\"number\">#{value}</div>"
        when :timer
          puts "Timer #{value}"
          socket.send "<div id=\"timer\">#{value}</div>"
        when :global_timer
          puts "Global Timer #{value}"
          socket.send "<div id=\"time-left\">#{value}</div>"
        else
          puts "No match"
        end

      when socket_status.receive?
        break
      else
        break if socket_status.closed?
      end

      Fiber.yield
    end
  end

  # start_user_timer eventing, socket_status

  eventing.emit({ :connected, Int64.new 0 })
end

Kemal.run port: 8082
