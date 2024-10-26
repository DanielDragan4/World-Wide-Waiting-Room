require "../powerup"
require "json"
require "./unit_multiplier"
require "./compound_interest"
require "./overcharge"
require "./timewarp"

class PowerupHarvest < Powerup
  STACK_KEY = "harvest_stack"
  ACTIVE_STACK_KEY = "active_stack"
  DURATION_KEY = "harvest_duration"
  BASE_PRICE = 500.0
  HARVEST_TIME = 3600

  def self.get_powerup_id
    "harvest"
  end

  def get_name
    "Harvest"
  end

  def get_description(public_key)
    "Collects the next hour's worth of units with the current units per second including boosts in the units per second for the hour, but pauses unit generation for that hour | #{get_harvest_amount(public_key).round(2)} units"
  end

  def get_harvest_amount (public_key)
    (@game.get_player_time_units_ps public_key) * HARVEST_TIME
  end

  def get_price (public_key)
    stack_size = get_player_stack_size(public_key)
    price = (BASE_PRICE * (stack_size ** 5)).round(2)
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)

    cooldown = @game.get_player_cooldown public_key, DURATION_KEY

    cooldown = cooldown.nil? ? true : cooldown


    return (((@game.get_player_time_units public_key) >= price) && (cooldown))
  end

  def max_stack_size (public_key)
    1
  end

  def get_player_stack_size(public_key)
    if public_key
      size = @game.get_key_value(public_key, STACK_KEY)
      size.to_s.empty? ? 1 : size.to_i
    else
      1
    end
  end

  def player_card_powerup_active_css_class(public_key)
    "border border-rounded border-[10px] border-transparent bg-[#e0f7ff] bg-opacity-80 shadow-[inset_0_0_10px_rgba(173,216,230,0.5),_0_0_15px_rgba(173,216,230,0.8),_0_0_20px_rgba(30,144,255,0.6)] hover:bg-[#d6f0ff] transition-all duration-200 ease-in-out"
  end

  def buy_action (public_key)

    if public_key
      if is_available_for_purchase(public_key)

        c_s = get_player_stack_size(public_key)
        price = get_price(public_key)

        puts "Purhcased Harvest!"
        @game.add_powerup public_key, PowerupHarvest.get_powerup_id
        @game.send_animation_event public_key, Animation::NUMBER_FLOAT, {"value" => "Harvested #{get_harvest_amount(public_key).round(2)} units!","color" => "#CFE9A0"}
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) + ( get_harvest_amount(public_key) - price))
        @game.set_player_time_units_ps(public_key, 0)

        duration = (@game.ts + HARVEST_TIME).to_s
        @game.set_key_value public_key, DURATION_KEY,  duration.to_s

        current_stack = c_s.nil? ? 0 : c_s

        new_stack = current_stack + 1
        @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)

        @game.set_key_value(public_key, DURATION_KEY, (@game.ts + HARVEST_TIME).to_s)


      end
    else
      nil
    end
    nil
  end

  def action (public_key, dt)
    puts "HARVEST ACTION #{@game.ts}"
  end

  def cleanup (public_key)
    if @game.get_player_cooldown public_key, DURATION_KEY
        puts "HARVEST CLEANUP #{@game.ts}"
        @game.set_player_time_units_ps(public_key, 1)
        @game.remove_powerup public_key, PowerupHarvest.get_powerup_id
    end
  end
end
