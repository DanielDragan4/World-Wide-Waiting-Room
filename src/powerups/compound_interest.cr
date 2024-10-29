require "../powerup.cr"

class PowerupCompoundInterest < Powerup
  BASE_PRICE = 10000.0
  KEY = "compound_interest_stack"
  LAST_BONUS_KEY = "compound_interest_bonus"
  INCREASE_KEY = "compound_interest_increase"
  BASE_BONUS_PER_10K = 1.01

  def new_multiplier(public_key) : Float64
    get_synergy_boosted_multiplier(public_key, BASE_BONUS_PER_10K - 1) + 1
  end

  def self.get_powerup_id
    "compound_interest"
  end

  def get_name
    "Compounding Interest"
  end

  def get_description (public_key)
    base_percent = new_multiplier(public_key)
    "For every 10,000 units you currently have, your unit production increases by #{((base_percent - 1) * 100).round(2)}%. One time purchase.\n
    Current bonus: #{get_bonus(public_key).round(2)}x"
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

  def get_last_bonus(public_key)
    last_bonus = @game.get_key_value(public_key, LAST_BONUS_KEY)
    last_bonus && last_bonus != "" ? last_bonus.to_f : 1.0
  end

  def get_bonus(public_key)
    return 1.0 unless is_purchased(public_key)
    units = @game.get_player_time_units(public_key)
    bonus_multiplier = new_multiplier(public_key) - 1
    bonus = (units / 10_000).floor
    1 + bonus * bonus_multiplier
  end

  def buy_action(public_key)
    puts "Purchasing Compound Interest"
    if public_key
      if !is_purchased(public_key) 
        powerup = PowerupCompoundInterest.get_powerup_id
        @game.inc_time_units(public_key, -BASE_PRICE)
        @game.set_key_value(public_key, KEY, "true")
        @game.add_powerup(public_key, powerup)
        puts "Purchased Compound Interest"
        apply_bonus(public_key)
      else
        return "Already Purchased"
      end
    else
      Nil
    end
  end

  def apply_bonus(public_key)
    current_rate = @game.get_player_time_units_ps(public_key)
    old_bonus = get_last_bonus(public_key)
    new_bonus = get_bonus(public_key)
  
    if old_bonus != new_bonus
      old_rate_increase = @game.get_key_value_as_float(public_key, INCREASE_KEY)
      if old_rate_increase > 0
        @game.inc_time_units_ps(public_key, -old_rate_increase)
      end
      base_rate = old_bonus.zero? ? current_rate : current_rate - old_rate_increase
      rate_increase = base_rate * (new_bonus - 1)
      
      @game.set_key_value(public_key, INCREASE_KEY, rate_increase)
      @game.inc_time_units_ps(public_key, rate_increase)
      @game.set_key_value(public_key, LAST_BONUS_KEY, new_bonus)
    end
  end

  def remove_bonus(public_key)
    rate_increase = @game.get_key_value_as_float(public_key, INCREASE_KEY)
  
    if rate_increase > 0
      @game.inc_time_units_ps(public_key, -rate_increase)
      @game.set_key_value(public_key, INCREASE_KEY, 0)
    end
    @game.set_key_value(public_key, LAST_BONUS_KEY, 1)
  end
  

  def action(public_key, dt)
    if public_key && is_purchased(public_key) && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id) && !(@game.has_powerup public_key, PowerupOverCharge.get_powerup_id) && !@game.has_powerup public_key, AfflictPowerupBreach.get_powerup_id
        apply_bonus(public_key)
    end
  end

  def cleanup(public_key)
    if public_key && is_purchased(public_key) && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id) && !(@game.has_powerup public_key, PowerupOverCharge.get_powerup_id) && !@game.has_powerup public_key, AfflictPowerupBreach.get_powerup_id
      remove_bonus(public_key)
    end
  end
end
