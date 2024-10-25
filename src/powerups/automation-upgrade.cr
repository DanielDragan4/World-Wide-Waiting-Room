require "../powerup.cr"

class PowerupAutomationUpgrade < Powerup
  BASE_PRICE = 1 #1000.0
  MULTIPLIER = 0.05
  KEY = "automation_upgrade_stack"
  PURCHASE_TIME_KEY = "automation_upgrade_purchase_time"
  PROCESSED_ACTIVES_KEY = "automation_upgrade_processed_actives"

  def new_multiplier(public_key) : Float64
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
      current_bonus = (adjusted_multiplier * actives_since_purchase * 100).round(2)
      
      "Adds an extra #{(adjusted_multiplier * 100).round(2)}% units/s for each active powerup purchased since this powerup was purchased (One time purchase).\n
      Current boost: #{current_bonus}% from #{actives_since_purchase} purchases."
    else
      adjusted_multiplier = new_multiplier(public_key)
      "Adds an extra #{(adjusted_multiplier * 100).round(2)}% units/s for each active powerup purchased after this powerup is purchased (One time purchase)."
    end
  end

  def is_stackable
    false
  end

  def get_price(public_key)
    BASE_PRICE
  end

  def is_available_for_purchase(private_key)
    !is_purchased(private_key)
  end

  def is_purchased(public_key)
    @game.get_key_value(public_key, KEY) == "true"
  end

  def get_actives_at_purchase(public_key) : Int32
    if public_key
      count = @game.get_key_value(public_key, PURCHASE_TIME_KEY)
      count.to_s.empty? ? 0 : count.to_i
    else
      0
    end
  end

  # Returns number of processed powerups from last time it was checked
  # Processed - actives_at_purchase = applicable number of actives
  def get_processed_actives(public_key) : Int32
    if public_key
      count = @game.get_key_value(public_key, PROCESSED_ACTIVES_KEY)
      count.to_s.empty? ? 0 : count.to_i
    else
      0
    end
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
    if public_key && @game.has_powerup(public_key, self.class.get_powerup_id)
      actives_at_purchase = get_actives_at_purchase(public_key)
      processed_actives = get_processed_actives(public_key)
      current_actives = @game.get_actives(public_key)

      new_actives = current_actives - processed_actives

      # if current number of active powerups differs from number processed, an active powerup was purchase since last check
      if new_actives > 0
        multiplier = new_multiplier(public_key)
        current_units_ps = @game.get_player_time_units_ps(public_key)

        bonus = 1 + (new_actives * multiplier)
        @game.set_player_time_units_ps(public_key, current_units_ps * bonus)
      
        # Saves new number of processed powerups
        @game.set_key_value(public_key, PROCESSED_ACTIVES_KEY, current_actives.to_s)
      end     
    end
  end
end
