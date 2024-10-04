require "kemal"
require "./templates"
require "./modules"

templates = Templates.new

eventing = Modules::Event
waiters = Modules::Waiters
global_timer = Modules::GlobalTimer
leaderboard = Modules::Leaderboard
persist_data = Modules::PersistData

post "/transfer" do |env|
  to = env.params.body["to"].as String
  from = env.params.body["from"].as String
  action = env.params.body["action"].as String

  if action == "give"
    puts "Taking from #{from} to #{to}"
    Modules::Waiters.give 10000, to, from
  elsif action == "take"
    puts "Giving to #{to} from #{from}"
    Modules::Waiters.take 10000, from, to
  end
end

get "/" do
  templates.render "index.html"
end

ws "/ws" do |socket|
  events = Channel(Event).new
  unique_waiter_id = Modules::Event.register_channel events

  Modules::Waiters.add_waiter unique_waiter_id

  socket_status = Channel(Nil).new

  socket.on_close do
    socket_status.close
    puts "User #{unique_waiter_id} disconnected."
    Modules::Waiters.remove_waiter unique_waiter_id
    Modules::Event.unregister_channel unique_waiter_id
    #Modules::Event.emit({ :disconnected, { "uid" => unique_waiter_id } of String => EventHashValue })
    #Modules::Leaderboard.compute
  end

  spawn do
    loop do
      select
      when event = events.receive
        name, value = event

        case name
        when :waiter_updated
          #if value["uid"] == unique_waiter_id
          #end
        when :global_timer
          time_left = value["time_left"]
          this_waiter = Modules::Waiters.get_waiter unique_waiter_id
          begin
            wc = templates.render "waiter-card.html", { "info" => this_waiter, "place" => Modules::Leaderboard.get_place unique_waiter_id }
            tl = templates.render "time-left.html", { "time_left" => time_left }
            lb = templates.render "leaderboard.html", {
              "waiters" => Modules::Leaderboard.leaderboard,
              "this_waiter" => this_waiter
            }
            socket.send "#{wc}#{tl}#{lb}"
          rescue
          end
        end

      when socket_status.receive?
        break
      else
        break if socket_status.closed?
      end

      Fiber.yield
    end
  end

  puts "User #{unique_waiter_id} connected."
  Modules::Event.emit({ :connected, { "uid" => unique_waiter_id } of String => EventHashValue })
  #Modules::Leaderboard.compute
  #Modules::GlobalTimer.emit
end

Kemal.run port: 8082
