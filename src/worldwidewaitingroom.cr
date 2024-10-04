require "kemal"
require "./templates"
require "./modules"

templates = Templates.new

eventing = Modules::Event
waiters = Modules::Waiters
global_timer = Modules::GlobalTimer
leaderboard = Modules::Leaderboard
persist_data = Modules::PersistData

post "/increase" do
  # Get UID here
  uid = Int64.new 1
  Modules::Event.emit({ :inc, { "uid" => uid } })
end

post "/decrease" do
  # Get UID here
  uid = Int64.new 1
  Modules::Event.emit({ :dec, { "uid" => uid } })
end

get "/" do
  templates.render "index.html"
end

ws "/ws" do |socket|
  events = Channel(Event).new
  unique_waiter_id = Modules::Event.register_channel events

  socket_status = Channel(Nil).new

  socket.on_close do
    socket_status.close
    Modules::Event.unregister_channel unique_waiter_id
    Modules::Event.emit({ :disconnected, { "uid" => unique_waiter_id } })
  end

  spawn do
    loop do
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
        when :connected
          puts "User #{value} connected."
        when :disconnected
          puts "User #{value} disconnected."
        when :leaderboard_updated
          puts "New leaderboard order #{value}"
        else
          puts "No match #{event}"
        end

      when socket_status.receive?
        break
      else
        break if socket_status.closed?
      end

      Fiber.yield
    end
  end

  Modules::Event.emit({ :connected, { "uid" => unique_waiter_id } })
end

Kemal.run port: 8082
