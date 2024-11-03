require "../powerup"

class PowerupSchrodinger < Powerup
  STACK_KEY = "schrodinger_stack"
  BASEBET = 0.5

  def self.get_powerup_id
    "schrodinger"
  end

  def category
    PowerupCategory::ACTIVE
  end

  def get_name
    "Schrodinger"
  end

  # def new_base_percent_increase(public_key) : Float64
  #   get_synergy_boosted_multiplier(public_key, (percent_increase public_key))
  # end

  def get_description(public_key)
    "Like Schrodinger's cat, both the win and lose of units is true. You won't know until you find out. Risk half of your units to either double them up or loose them."
  end

  def get_price (public_key)
    amount = ((@game.get_player_time_units public_key) * BASEBET).round(2)
    amount
  end

  def is_available_for_purchase(public_key)
    current_units = @game.get_player_time_units public_key
    current_units > 0
  end

  def win_or_loose
    r = Random.new
    gamble_value = r.rand

    if gamble_value >= 0.51
      true
    else
      false
    end
  end

  # def get_player_stack_size(public_key)
  #   size = @game.get_key_value(public_key, STACK_KEY)
  #   size_i = size.to_i?
  #   size_i ||= 1
  #   size_i
  # end

  def buy_action (public_key)
    if is_available_for_purchase(public_key)
      puts "Purchased Schrodinger!"

      bet_amount = get_price public_key

      @game.inc_time_units public_key, -(bet_amount)

      won_loose = win_or_loose

      if won_loose
        @game.inc_time_units public_key, (bet_amount * 2)
      end

    else
      puts "GET SOME UNITS"
    end
  end

  def action (public_key, dt)
  end
end
