require "../powerup"
require "json"
require "./unit_multiplier"
require "./compound_interest"

class PowerupOverCharge < Powerup
  STACK_KEY = "overcharge_stack"
  ACTIVE_STACK_KEY = "overcharge_active_stack"
  BASE_PRICE = 200.0
  UNIT_MULTIPLIER = 5.0
  DURATION = 120
  KEY_DURATION = "overcharge_duration"

  def self.get_powerup_id
    "overcharge"
  end

  def get_name
    "Over Charge"
  end

  def is_stackable
    true
  end

  def get_description(public_key)
    if public_key
        a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
        active_stack = a_s.nil? ? 1 : a_s + 1
        amount = (new_multiplier(public_key) ** active_stack.to_i)
        "Increases unit production by #{amount}x for 2 min, but disables all passive powerups while active. Price increases exponentially."
    else
        "Increases unit production by 5x for 2 min, but disables all passive powerups while active. Price increases exponentially."
    end
  end

  def get_price (public_key)
    stack_size = get_player_stack_size(public_key)
    price = (BASE_PRICE * (stack_size ** 4)).round(2)
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)

    return ((@game.get_player_time_units public_key) >= price)
  end

  def max_stack_size (public_key)
    500
  end

  def new_multiplier(public_key) : Float64
    get_synergy_boosted_multiplier(public_key, UNIT_MULTIPLIER)
  end

  def get_player_stack_size(public_key)
    if public_key
      size = @game.get_key_value(public_key, STACK_KEY)
      size.to_s.empty? ? 1 : size.to_i
    else
      1
    end
  end

  def buy_action (public_key)
    if public_key
      if is_available_for_purchase(public_key)
        @game.add_powerup public_key, PowerupOverCharge.get_powerup_id
        @game.add_active public_key

        current_stack = get_player_stack_size(public_key)
        price = get_price(public_key)

        puts "Purhcased Over Charge!"
        @game.add_powerup public_key, PowerupOverCharge.get_powerup_id
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) - price)

        a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
        active_stack = a_s.nil? ? 0 : a_s

        durations = Array(String)
        passive_powerups = Array(Bool)

        if (!active_stack.nil?) && (active_stack > 0)
            durations = Array(String).from_json(@game.get_key_value public_key, KEY_DURATION)
            durations << ((@game.ts + DURATION).to_s)
        else
            durations = [(@game.ts + DURATION).to_s]
        end

        @game.set_key_value public_key, KEY_DURATION,  durations.to_json

        new_stack = current_stack + 1
        @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)

        if !active_stack.nil?
            new_active_stack = active_stack + 1
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, new_active_stack.to_s)
        else
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, "1")
        end

      else
        puts "Your Dont have Enough units Left"
      end
    else
      nil
    end
  end

  def action (public_key, dt)
    puts "OVERCHARGE ACTION #{@game.ts}"
    if public_key && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id)
        a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
        active_stack = a_s.nil? ? 0 : a_s

        unit_rate = @game.get_player_time_units_ps(public_key)
        overcharge_rate = unit_rate * (new_multiplier(public_key) ** active_stack.to_i)
        @game.set_player_time_units_ps(public_key, overcharge_rate)
    end
  end

  def cleanup (public_key)
    if public_key
      a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
      active_stack = a_s.nil? ? 0 : a_s
        if !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id)
        unit_rate = @game.get_player_time_units_ps(public_key)
        overcharge_rate = unit_rate / (new_multiplier(public_key) ** active_stack.to_i)
        @game.set_player_time_units_ps(public_key, overcharge_rate)
        end

        durations = Array(String).from_json(@game.get_key_value public_key, KEY_DURATION)

      if (!durations.nil?) && (!durations.empty?) && (!active_stack.nil?)
          duration = durations[0].to_i
          current_time = @game.ts

          if (duration < current_time)
            durations.delete_at(0)
            @game.set_key_value public_key, KEY_DURATION,  durations.to_json

            new_active_stack = active_stack - 1
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, new_active_stack.to_s)

            if(durations.size == 0)
                @game.remove_powerup public_key, PowerupOverCharge.get_powerup_id
            end
            @game.set_key_value public_key, ACTIVE_STACK_KEY, (active_stack -1).to_s
        else
            nil
        end
      end
    end
  end
end
