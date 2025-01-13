require "../powerup"
require "big"
require "json"

class PowerupRelativisticShift < Powerup
  STACK_KEY = "relativistic_shift_stack"
  BASE_PRICE = BigFloat.new 100_000.0
  UNIT_MULTIPLIER = BigFloat.new 4.0
  DURATION = 28_800
  KEY_DURATION = "relativistic_shift_duration"

  def category
    PowerupCategory::PASSIVE
  end

  def new_multiplier(public_key) : BigFloat
    get_synergy_boosted_multiplier(public_key, UNIT_MULTIPLIER)
  end

  def self.get_powerup_id
    "relativistic_shift"
  end

  def get_name
    "Relativistic Shift"
  end

  def is_stackable
    false
  end


  def get_popup_info (public_key) : PopupInfo
    durations = @game.get_key_value_as_int public_key, KEY_DURATION

    pi = PopupInfo.new
    pi["Time Left"] = @game.get_timer_time_left public_key, KEY_DURATION
    pi["Units/s Boost"] = "#{(new_multiplier(public_key)).round(2)}x"
    pi
  end

  def get_description(public_key)
    amount = (new_multiplier(public_key)).round(2)
    unit_rate =  BigFloat.new(@game.get_player_time_units_ps(public_key))
    estimate = unit_rate * amount
    "<strong>+#{amount}x (#{estimate.round(2)})</strong><br>
    <strong>Duration:</strong> #{DURATION/3600} Hours<br>
    <strong>Stackable:</strong> No<br>
    <strong>Toggleable:</strong> No<br>
    Boosts Units/s. Disables Overcharge and Time Warp when active"
  end

  def get_price (public_key)
    alterations = @game.get_cached_alterations
    stack_size = get_player_stack_size(public_key)

    price = BASE_PRICE  * (stack_size ** (BigInt.new 7))
    price = @game.increase_number_by_percentage price, BigFloat.new alterations.passive_price
    price.round(2)
  end

  def player_card_powerup_icon (public_key)
    "/relativistic_shift.png"
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)
    is_active = !(@game.has_powerup public_key, PowerupRelativisticShift.get_powerup_id)

    return (((@game.get_player_time_units public_key) >= price) && is_active)
  end

  def max_stack_size (public_key)
    10000
  end

  def get_player_stack_size(public_key)
    @game.get_key_value_as_int(public_key, STACK_KEY, BigInt.new 1)
  end

  def buy_action (public_key)

    if public_key
      if is_available_for_purchase(public_key)

        c_s = get_player_stack_size(public_key)
        current_stack = c_s.nil? ? 0 : c_s
        price = get_price(public_key)

        puts "Purhcased Relativistic Shift!"
        @game.add_powerup public_key, PowerupRelativisticShift.get_powerup_id
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) - price)

        durations = (@game.ts + DURATION).to_s
        @game.set_key_value public_key, KEY_DURATION, durations

        new_stack = current_stack + 1
        @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)
        end

      else
        puts "Your Dont have Enough units Left"
      end
    nil
  end

  def action (public_key, dt)
    if public_key && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id) && (!(@game.has_powerup(public_key, AfflictPowerupBreach.get_powerup_id)) || (@game.has_powerup(public_key, PowerupForceField.get_powerup_id)))
        unit_rate =  BigFloat.new(@game.get_player_time_units_ps(public_key))
        relativistic_shift_rate = (unit_rate * (new_multiplier(public_key))) - unit_rate

        @game.inc_time_units_ps public_key, relativistic_shift_rate.round(2)
    end
  end

  def cleanup (public_key)
    if public_key

      durations = @game.get_key_value_as_float public_key, KEY_DURATION
      if (!durations.nil?)
        duration = durations
        current_time = @game.ts

          if (duration < current_time)
            @game.remove_powerup public_key, PowerupRelativisticShift.get_powerup_id
          else
            nil
          end
      end
    end
  end
end
