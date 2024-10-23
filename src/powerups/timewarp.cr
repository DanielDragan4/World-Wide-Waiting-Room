require "../powerup"
require "json"

class PowerupTimeWarp < Powerup
  STACK_KEY = "timewarp_stack"
  ACTIVE_STACK_KEY = "active_stack"
  BASE_PRICE = 100.0
  UNIT_MULTIPLIER = 2.0
  DURATION = 600
  KEY_DURATION = "timewarp_duration"

  def self.get_powerup_id
    "timewarp"
  end

  def get_name
    "Time Warp"
  end

  def is_stackable
    true
  end

  def get_description(public_key)
    "Doubles your units per second for the next 10 minutes. Stacks multiplicatively with other buffs. Prices increase with each additional purchase"
  end

  def get_price (public_key)
    stack_size = get_player_stack_size(public_key)
    price = (BASE_PRICE * (stack_size ** 3)).round(2)
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)

    return ((@game.get_player_time_units public_key) >= price)
  end

  def max_stack_size (public_key)
    500
  end

  def get_player_stack_size(public_key)
    if public_key
      size = @game.get_key_value(public_key, STACK_KEY)
      size.to_s.empty? ? 1 : size.to_i
    else
      1
    end
  end

  def get_player_active_stack_size(public_key)
    if public_key
      size = @game.get_key_value(public_key, STACK_KEY)
      size.to_s.empty? ? 0 : size.to_i
    else
      0
    end
  end

  def buy_action (public_key)

    if public_key
      if is_available_for_purchase(public_key)

        current_stack = get_player_stack_size(public_key)
        price = get_price(public_key)

        puts "Purhcased Time Warp!"
        @game.add_powerup public_key, PowerupTimeWarp.get_powerup_id
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) - price)

        a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
        active_stack = a_s.nil? ? 0 : @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY

        durations = Array(String)
        if (!active_stack.nil?) && (active_stack > 0) 
            durations = Array(String).from_json(@game.get_key_value public_key, KEY_DURATION)
            durations << ((@game.ts + DURATION).to_s)
        else
            durations = [(@game.ts + DURATION).to_s]
        end
        @game.set_key_value public_key, KEY_DURATION,  durations.to_json

        unit_rate = @game.get_player_time_units_ps(public_key)
        timewarp_rate = unit_rate * UNIT_MULTIPLIER
        @game.set_player_time_units_ps(public_key, timewarp_rate)

        new_stack = current_stack + 1
        @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)

        if !active_stack.nil?
            new_active_stack = active_stack + 1 
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, new_active_stack.to_s)
        end

      else
        puts "Your Dont have Enough units Left"
      end
    else
      nil
    end
    nil
  end

  def action (public_key, dt)
  end

  def cleanup (public_key)
    if public_key
      durations = Array(String).from_json(@game.get_key_value public_key, KEY_DURATION)

      a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
      active_stack = a_s.nil? ? 0 : @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY

      if (!durations.nil?) && (!durations.empty?) && (!active_stack.nil?)
          duration = durations[0].to_i
          current_time = @game.ts
          
          if (duration < current_time)
              durations.delete_at(0)
              @game.set_key_value public_key, KEY_DURATION,  durations.to_json

              unit_rate = @game.get_player_time_units_ps(public_key)
              timewarp_rate = unit_rate / UNIT_MULTIPLIER
              @game.set_player_time_units_ps(public_key, timewarp_rate)

              
              new_active_stack = active_stack - 1  
              @game.set_key_value(public_key, ACTIVE_STACK_KEY, new_active_stack.to_s)
          else
              nil
          end
      end
  end
  end
end
