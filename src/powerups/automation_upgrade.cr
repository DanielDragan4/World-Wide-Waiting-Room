require "../powerup.cr"

class PowerupAutomationUpgrade < Powerup
  BASE_PRICE = BigFloat.new 1000.0
  MULTIPLIER = BigFloat.new 0.05
  KEY = "automation_upgrade_stack"
  PURCHASE_TIME_KEY = "automation_upgrade_purchase_time"
  PROCESSED_ACTIVES_KEY = "automation_upgrade_processed_actives"
  BONUS_APPLIED_KEY = "automation_upgrade_bonus_applied"

  def category
    PowerupCategory::PASSIVE
  end

  def new_multiplier(public_key) : BigFloat
    get_synergy_boosted_multiplier(public_key, MULTIPLIER)
  end

  def self.get_powerup_id
    "automation_upgrade"
  end

  def get_name
    "Automation Upgrade"
  end

  def get_description (public_key)
    if is_purchased(public_key)
      adjusted_multiplier = new_multiplier(public_key)
      actives_at_purchase = get_actives_at_purchase(public_key)
      current_actives = @game.get_actives(public_key)
      actives_since_purchase = [current_actives - actives_at_purchase, 0].max
      current_bonus = ((adjusted_multiplier * 100).round / 100 * actives_since_purchase * 100).round(2)

      "<strong>+#{current_bonus}% Units/s:</strong><br>
      <strong>Owned:</strong> #{actives_since_purchase}<br>
      <strong>Stackable:</strong> Yes<br>
      <strong>Toggleable:</strong> No<br>
      Each active powerup purchased increases the number owned and Units/s by #{(adjusted_multiplier * 100).round}%."

    else
      adjusted_multiplier = new_multiplier(public_key)
      "<strong>Owned:</strong> 0<br>
      <strong>Stackable:</strong> Yes<br>
      <strong>Toggleable:</strong> No<br>
      Each active powerup purchased, after buying, increases the number owned and Units/s by #{(adjusted_multiplier * 100).round}%."
    end
  end

  def is_stackable
    false
  end

  def get_price(public_key)
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage BASE_PRICE, BigFloat.new alterations.active_price
  end

  def is_available_for_purchase(public_key)
    !is_purchased(public_key) && ((@game.get_player_time_units public_key) >= get_price(public_key))
  end

  def is_purchased(public_key)
    @game.get_key_value(public_key, KEY) == "true"
  end

  def get_actives_at_purchase(public_key)
    @game.get_key_value_as_int(public_key, PURCHASE_TIME_KEY, BigInt.new 0)
  end

  # Returns number of processed powerups from last time it was checked
  # Processed - actives_at_purchase = applicable number of actives
  def get_processed_actives(public_key)
    @game.get_key_value_as_int(public_key, PROCESSED_ACTIVES_KEY, BigInt.new 0)
  end

  def new_prestige(public_key, game : Game)
    actives_at_purchase = get_actives_at_purchase(public_key)
    current_actives = @game.get_actives(public_key)
    game.set_key_value(public_key, PURCHASE_TIME_KEY, current_actives.to_s)
  end

  def buy_action(public_key)
    return nil if !public_key

    price = get_price(public_key)
    units = @game.get_player_time_units(public_key)
    if units > price && !is_purchased(public_key)
      powerup = PowerupAutomationUpgrade.get_powerup_id

      # Store current active count before any modifications
      current_actives = @game.get_actives(public_key)

      # Deduct price and add powerup
      @game.inc_time_units(public_key, -price)
      @game.add_powerup(public_key, powerup)
      @game.set_key_value(public_key, KEY, "true")

      # Stores number of active powerups at time of purchase
      @game.set_key_value(public_key, PURCHASE_TIME_KEY, current_actives.to_s)

      # Initializes count of processed active powerups (initially equal to current number actives)
      @game.set_key_value(public_key, PROCESSED_ACTIVES_KEY, current_actives.to_s)

      puts "Purchased Automation Upgrade"
      return "Purchased Automation Upgrade"
    else
      "You don't have enough points to purchase Automation Upgrade"
    end
  end

  def action(public_key, dt)
    if public_key && is_purchased(public_key)
      actives_at_purchase = get_actives_at_purchase(public_key)
      current_actives = @game.get_actives(public_key)

      # Calculate number of actives purchased since automation upgrade
      actives_since_purchase = [current_actives - actives_at_purchase, 0].max

      # Only apply the bonus if neither harvest nor overcharge is active
      if !(@game.has_powerup(public_key, PowerupHarvest.get_powerup_id) || @game.has_powerup(public_key, PowerupOverCharge.get_powerup_id) || @game.has_powerup public_key, AfflictPowerupBreach.get_powerup_id)
        multiplier = (new_multiplier(public_key) * 100).round / 100
        current_units_ps = @game.get_player_time_units_ps(public_key)

        # Apply bonus based on total actives since purchase
        bonus = 1 + (actives_since_purchase * multiplier)
        increased_rate = current_units_ps * bonus - current_units_ps

        @game.inc_time_units_ps(public_key, increased_rate)
      end

      # Update processed actives to current state
      @game.set_key_value(public_key, PROCESSED_ACTIVES_KEY, current_actives.to_s)
    end
  end

end
