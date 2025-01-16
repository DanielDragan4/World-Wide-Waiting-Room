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
    fremen_boost = get_fremen_boost(public_key)
    auto_boost = get_auto_upgrade_boost(public_key)

    base_generation = BASE_GENERATION
    total_multiplier = base_generation * unit_multiplier * compound_interest_boost * fremen_boost * auto_boost

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

  def get_fremen_boost(public_key) : BigFloat
    fremen_powerup = @game.get_powerup_classes[PowerupAmishLife.get_powerup_id]
    fremen_powerup = fremen_powerup.as PowerupAmishLife
    BigFloat.new(fremen_powerup.get_unit_boost(public_key))
  end

  def get_auto_upgrade_boost(public_key) : BigFloat
    auto_upgrade_powerup = @game.get_powerup_classes[PowerupAutomationUpgrade.get_powerup_id]
    auto_upgrade_powerup = auto_upgrade_powerup.as PowerupAutomationUpgrade
    auto_upgrade_powerup.get_auto_boost(public_key)
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

    description = "<strong>Duration:</strong> #{VAULT_DURATION/3600} Hour<br><strong>Stackable:</strong> No<br><br> Temporarily store <b>half</b> of your units in a vault. These units are immune to all effects."

    if vault_units > 0
      description += "<br><strong>Vaulted:</strong> #{(@game.format_units vault_units.round(2))}"
      description += "<br><strong>Remaining:</strong> #{@game.format_time(time_remaining)}"
    end
    return description
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
