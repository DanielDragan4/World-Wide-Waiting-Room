require "../powerup.cr"
require "./cosmic_breakthrough"

class PowerupUnitVault < Powerup
  BASE_PRICE = BigFloat.new(25.0)
  BASE_GENERATION = BigFloat.new(0.5)
  KEY = "unit_vault_active"
  VAULT_UNITS_KEY = "unit_vault_stored_units"
  VAULT_TIMESTAMP_KEY = "unit_vault_timestamp"
  VAULT_GENERATION_RATE_KEY = "unit_vault_generation_rate"
  VAULT_DURATION = 60 * 60

  def category
    PowerupCategory::DEFENSIVE
  end

  # Method to calculate to overall unit generation within the vault at time of purchase
  def calculate_vault_generation_multiplier(public_key) : BigFloat
    unit_multiplier = get_unit_multiplier(public_key)
    compound_interest_boost = get_compound_interest_boost(public_key)

    base_generation = BASE_GENERATION
    total_multiplier = base_generation * unit_multiplier * compound_interest_boost

    total_multiplier
  end

  # Helper method to get total multiplier from Unit Multiplier
  def get_unit_multiplier(public_key) : BigFloat
    unit_multi_powerup = @game.get_powerup_classes[PowerupUnitMultiplier.get_powerup_id]
    unit_multi_powerup = unit_multi_powerup.as PowerupUnitMultiplier
    stack_size = unit_multi_powerup.get_player_stack_size(public_key) + 1

    unit_multi_powerup.new_multiplier(public_key) * stack_size
  end

  # Helper method to get total current boost value from Compound Interest
  def get_compound_interest_boost(public_key) : BigFloat
    compound_powerup = @game.get_powerup_classes[PowerupCompoundInterest.get_powerup_id]
    compound_powerup = compound_powerup.as PowerupCompoundInterest
    compound_powerup.get_unit_boost(public_key)
  end

  def new_multiplier(public_key) : BigFloat
    # Retrieves the stored generation rate for this vault
    stored_rate_str = @game.get_key_value(public_key, VAULT_GENERATION_RATE_KEY)

    # In case no rate exists
    if stored_rate_str.to_s.empty?
      return calculate_vault_generation_multiplier(public_key)
    end

    BigFloat.new(stored_rate_str)
  end

  def self.get_powerup_id
    "unit_vault"
  end

  def get_name
    "Unit Vault"
  end

  def get_description(public_key)
    vault_units = get_vaulted_units(public_key)
    time_remaining = get_time_remaining(public_key)

    description = "Store 50% of your current units in a vault for the next hour. These units are immune to all effects (both friendly and hostile) and cannot be used until the timer runs out.
    Unit generation on vaulted units is decreased to 50% of current base production (including all passive effects at time of purchase).<br>"

    if vault_units > 0
      description += "<br>Currently Vaulted: #{(format_vaulted_units vault_units.round(2))} units\n "
      description += "<br>Time Remaining: #{format_time(time_remaining)}"
    end
    return description
  end


  # Formats vaulted units with commas for scientific notation based on value
  def format_vaulted_units(value : BigFloat)
    if value < 1_000_000
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

  #Helper method to format timer
  def format_time(seconds : Int32) : String
    hours = (seconds / 3600).floor.to_i
    minutes = ((seconds % 3600) / 60).floor.to_i
    secs = (seconds % 60).floor.to_i

    "#{hours}h #{minutes}m #{secs}s"
  end

  def is_stackable
    false
  end

  def get_price(public_key)
    alterations = @game.get_cached_alterations
    price = @game.get_player_time_units(public_key) / 2
    @game.increase_number_by_percentage price, BigFloat.new alterations.defensive_price
  end

  def is_available_for_purchase(public_key)
    !is_purchased(public_key)
  end

  def is_purchased(public_key) : Bool
    @game.get_key_value(public_key, KEY) == "true"
  end

  def get_vaulted_units(public_key) : BigFloat
    if public_key
      units = @game.get_key_value(public_key, VAULT_UNITS_KEY)
      units.to_s.empty? ? BigFloat.new(0) : BigFloat.new(units)
    else
      BigFloat.new(0)
    end
  end

  def get_time_remaining(public_key) : Int32
    if public_key
      timestamp = @game.get_key_value(public_key, VAULT_TIMESTAMP_KEY)
      return 0 if timestamp.to_s.empty?

      vault_start = BigFloat.new(timestamp)
      time_passed = @game.ts - vault_start
      remaining = BigFloat.new(VAULT_DURATION) - time_passed

      [remaining.to_i, 0].max
    else
      0
    end
  end

  def buy_action(public_key)
    if public_key
      if is_purchased(public_key)
        return "A vault is already in progress."
      end
      price = get_price(public_key).round
      units = @game.get_player_time_units(public_key)

      if units >= price
        vault_amount = BigFloat.new(units * 0.5).round

        vault_generation_rate = calculate_vault_generation_multiplier(public_key)

        @game.inc_time_units(public_key, -price)
        @game.add_powerup(public_key, PowerupUnitVault.get_powerup_id)

        @game.set_key_value(public_key, VAULT_UNITS_KEY, vault_amount.to_s)
        @game.set_key_value(public_key, VAULT_TIMESTAMP_KEY, @game.ts.to_s)
        @game.set_key_value(public_key, VAULT_GENERATION_RATE_KEY, vault_generation_rate.to_s)

        @game.set_key_value(public_key, KEY, "true")
        "Successfully vaulted #{vault_amount} units."
      else
        "You don't have enough units to purchase Unit Vault"
      end
    else
      nil
    end
  end

  def action(public_key, dt)
    if public_key && is_purchased(public_key)
      vaulted_units = get_vaulted_units(public_key)
      time_remaining = get_time_remaining(public_key)

      if vaulted_units > BigFloat.new(0) && time_remaining > 0
        generation_rate = new_multiplier(public_key)

        @game.set_key_value(public_key, VAULT_UNITS_KEY, (vaulted_units + generation_rate).to_s)
      end
    end
  end

  def cleanup(public_key)
    if public_key && is_purchased(public_key)
      vaulted_units = get_vaulted_units(public_key)
      time_remaining = get_time_remaining(public_key)

      if vaulted_units > BigFloat.new(0) && time_remaining <= 0
        @game.inc_time_units(public_key, vaulted_units)
        @game.set_key_value(public_key, VAULT_UNITS_KEY, "")
        @game.set_key_value(public_key, VAULT_TIMESTAMP_KEY, "")
        @game.set_key_value(public_key, KEY, "")
        @game.remove_powerup(public_key, PowerupUnitVault.get_powerup_id)
      end
    end
  end
end
