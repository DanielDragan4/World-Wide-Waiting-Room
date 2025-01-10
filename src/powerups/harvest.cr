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
  BASE_PRICE = BigFloat.new 500.0
  HARVEST_TIME = 3600
  COOLDOWN_DURATION = 60 * 60 * 6
  COOLDOWN_KEY = "harvest cooldown"

  def category
    PowerupCategory::ACTIVE
  end

  def self.get_powerup_id
    "harvest"
  end

  def get_name
    "Wormhole"
  end

  def player_card_powerup_icon (public_key)
    "/harvest.png"
  end

  def get_description(public_key)
    units = ((@game.get_player_frame_ups public_key) * HARVEST_TIME).round(0)
    "Collects the next hour's worth of units based on current unit production rate, but pauses unit generation for the next hour. Has a 6 hour cooldown.
    <br>Use to gain #{(format_harvest_units units.round(2))} units. "
  end

  # Formats vaulted units with commas for scientific notation based on value
  def format_harvest_units(value : BigFloat)
    if value < 1_000_000_000
      integer_part, decimal_part = value.to_s.split(".")
      formatted_integer = integer_part.reverse.chars.each_slice(3).map(&.join).join(",").reverse
      decimal_part ? "#{formatted_integer}.#{decimal_part}" : formatted_integer
    else
      format_in_scientific_notation(value)
    end
  end

  # Helper method to format numbers in scientific notation
  def format_in_scientific_notation(value : BigFloat) : String
    exponent = Math.log10(value).floor
    base = value / (10.0 ** exponent)
    "#{base.round(2)} x 10^#{exponent}"
  end

  def cooldown_seconds_left(public_key)
    @game.get_timer_seconds_left public_key, COOLDOWN_KEY
  end

  def get_popup_info (public_key) : PopupInfo
    pi = PopupInfo.new
    pi["Time Left"] = @game.get_timer_seconds_left public_key, DURATION_KEY
    pi
  end

  def get_harvest_amount (public_key)
    (@game.get_player_frame_ups public_key) * HARVEST_TIME
  end

  def get_price (public_key)
    stack_size = get_player_stack_size(public_key)
    price = (BASE_PRICE * (stack_size ** 4)).round(2)
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage price, BigFloat.new alterations.active_price
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)

    timer_expired = @game.is_timer_expired public_key, DURATION_KEY
    cooldown_expired = @game.is_timer_expired public_key, COOLDOWN_KEY

    return ((@game.get_player_time_units public_key) >= price) && timer_expired && cooldown_expired
  end

  def max_stack_size (public_key)
    1
  end

  def get_player_stack_size(public_key)
    @game.get_key_value_as_int(public_key, STACK_KEY, BigInt.new 1)
  end

  def buy_action (public_key)
    if is_available_for_purchase(public_key)
      c_s = get_player_stack_size(public_key)
      new_stack = c_s + 1

      price = get_price(public_key)

      puts "Purhcased Harvest!"
      @game.add_powerup public_key, PowerupHarvest.get_powerup_id
      @game.add_active public_key
      @game.inc_time_units public_key, (get_harvest_amount public_key)
      @game.disable_unit_generation public_key
      @game.set_timer public_key, DURATION_KEY, HARVEST_TIME
      @game.set_timer public_key, COOLDOWN_KEY, COOLDOWN_DURATION
      @game.set_key_value public_key, STACK_KEY, new_stack.to_s
      @game.send_animation_event public_key,
        Animation::NUMBER_FLOAT,
        {"value" => "Harvested #{get_harvest_amount(public_key).round(2)} units!","color" => "#CFE9A0"}
    end
  end

  def action (public_key, dt)
    puts "HARVEST ACTION #{@game.ts}"
  end

  def cleanup (public_key)
    if @game.is_timer_expired public_key, DURATION_KEY
      puts "HARVEST CLEANUP #{@game.ts}"
      @game.enable_unit_generation public_key
      @game.remove_powerup public_key, PowerupHarvest.get_powerup_id
    end
  end
end
