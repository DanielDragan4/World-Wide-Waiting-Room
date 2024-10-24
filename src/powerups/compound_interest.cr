require "../powerup.cr"

class PowerupCompoundInterest < Powerup
  BASE_PRICE = 10000.0
  KEY = "compound_interest_stack"
  LAST_BONUS_KEY = "compound_interest_bonus"
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
    "Your units/s increases by #{((base_percent - 1) * 100).round(2)}% for every 10,000 units you currently have. One time purchase.\n
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
    bonus_multiplier = new_multiplier(public_key)
    bonus = (units / 10000).floor
    1.0 + (bonus * bonus_multiplier)
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
      old_rate = current_rate / old_bonus
      new_rate = old_rate * new_bonus
      @game.set_player_time_units_ps(public_key, new_rate)
      @game.set_key_value(public_key, LAST_BONUS_KEY, new_bonus.to_s)
    end
  end

  def action(public_key, dt)
    if public_key && is_purchased(public_key)
        apply_bonus(public_key)
    end
  end
end
