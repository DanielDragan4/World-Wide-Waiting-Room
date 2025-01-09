require "../powerup"
require "big"
require "json"

class PowerupAmishLife < Powerup
  STACK_KEY = "amish_life_stack"
  ACTIVE_STACK_KEY = "amish_active_stack"
  BASE_PRICE = BigFloat.new 1.0
  UNIT_MULTIPLIER = BigFloat.new 2.0
  DURATION = 60 * 60 * 8
  KEY_DURATION = "amish_life_duration"
  DEBUFF_RATE = BigFloat.new 0.1

  def category
    PowerupCategory::PASSIVE
  end

  def self.get_powerup_id
    "amish_life"
  end

  def get_name
    "Fremen Life"
  end

  def get_popup_info (public_key) : PopupInfo
    durations = @game.get_key_value public_key, KEY_DURATION
    e_d = enable_disable(public_key)

    pi = PopupInfo.new
    pi["Time Left"] = (DURATION - BigFloat.new(durations)).to_s
    pi["Boost State"] = e_d
    pi["Units/s Boost"] = "#{(get_unit_boost(public_key)).round(2)}x"
    pi
  end

  def get_description(public_key)
    e_d = enable_disable(public_key)

    "Permanently multiplies unit production by 2x once the duration expires.
    <br>However, in order to recive the boost, for 8 hours total unit generation is reduced by 90%.
    <br> You are able to pause the duration at any point without restarting the duration by purchasing the powerup again. The duration
    only ticks down while you are online. The duration does not tick down during Wormholes unit generation cooldown.
    <br> Current State: #{e_d}"
  end

  def get_price (public_key)
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage BASE_PRICE, BigFloat.new alterations.passive_price
  end

  def player_card_powerup_icon (public_key)
    "/amish.png"
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)

    return ((@game.get_player_time_units public_key) >= price)
  end

  def get_player_stack_size(public_key)
    @game.get_key_value_as_int(public_key, STACK_KEY, BigInt.new 0)
  end

  def get_player_active_stack_size(public_key)
    @game.get_key_value_as_int(public_key, ACTIVE_STACK_KEY, BigInt.new 0)
  end

  def get_unit_boost(public_key)
    return 1.0 if get_player_stack_size(public_key) == 0
    stack = get_player_stack_size(public_key)
    multiplyer = UNIT_MULTIPLIER ** stack

    multiplyer
  end

  def enable_disable(public_key) : String
    a_s = get_player_active_stack_size(public_key)
    active_stack = a_s.nil? ? 0 : a_s

      if active_stack > 0
        return "Enabled"
      else
        return "Disabled"
    end
  end

  def buy_action (public_key)

    if public_key
      if is_available_for_purchase(public_key)
        price = get_price(public_key)
        puts "Started Fremen Life!"

        @game.inc_time_units(public_key, -price)

        a_s = get_player_active_stack_size(public_key)
        active_stack = a_s.nil? ? 0 : a_s

        duration = @game.get_key_value_as_int(public_key, KEY_DURATION, BigInt.new 0)

        if active_stack > 0
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, "0")
        else
            @game.add_powerup public_key, PowerupAmishLife.get_powerup_id
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, "1")
            if(duration == 0)
                @game.set_key_value(public_key, KEY_DURATION, "0")
            end
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
    if public_key && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id)
        unit_rate =  BigFloat.new(@game.get_player_time_units_ps(public_key))

        active_stack = get_player_active_stack_size(public_key)
        duration = @game.get_key_value_as_int(public_key, KEY_DURATION, BigInt.new 0)
        amish_rate = (unit_rate * (get_unit_boost(public_key))) - unit_rate


        if  active_stack > 0
            debuff_rate = (unit_rate * (DEBUFF_RATE * get_unit_boost(public_key))) - unit_rate
            @game.inc_time_units_ps public_key, debuff_rate.round(2)
            new_duration = duration + 1
            @game.set_key_value(public_key, KEY_DURATION, new_duration.to_s)
        else
            @game.inc_time_units_ps public_key, amish_rate.round(2)
        end
    end
  end

  def cleanup (public_key)
    duration = @game.get_key_value_as_int(public_key, KEY_DURATION, BigInt.new 0)

    if ((get_player_active_stack_size(public_key) > 0) && (duration >= DURATION))
        c_s = get_player_stack_size(public_key)
        current_stack = c_s.nil? ? 0 : c_s

        @game.set_key_value(public_key, KEY_DURATION, "0")
        new_stack = current_stack + 1
        @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)
    end
  end
end
