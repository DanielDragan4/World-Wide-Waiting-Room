require "../powerup"

class PowerupSchrodinger < Powerup
  STACK_KEY = "schrodinger_stack"
  BET_AMOUNT = 0.50
  #BET_AMOUNT_KEY = "schrodinger_bet"
  BET_PROBABILITY_KEY = "schrodinger_prob"
  MIN_WIN_PROB = 0.3
  MAX_WIN_PROB = 0.7
  HOUSE_EDGE = 0.05

  def self.get_powerup_id
    "schrodinger"
  end

  def category
    PowerupCategory::ACTIVE
  end

  def get_name
    "Schrödinger"
  end

  # def new_base_percent_increase(public_key) : Float64
  #   get_synergy_boosted_multiplier(public_key, (percent_increase public_key))
  # end

  def get_description(public_key)
    multi = get_multi(public_key)
    if multi < 0
      multi = 0
    end
    "<strong>Bet Amount:</strong> #{(BET_AMOUNT*100)}%<br>
    <strong>Win Probability:</strong> #{((get_bet_prob(public_key))*100)}%<br>
    <strong>Win Multiplier:</strong> #{(multi + 1).round(2)}<br>
    <br>
    Gamble a portion of your units based on the above predetermined odds."
  end

  def get_price (public_key)
    amount = ((@game.get_player_time_units public_key) * BET_AMOUNT).round(2)
    amount
  end

  def get_bet_prob(public_key)
    prob = @game.get_key_value_as_float public_key, BET_PROBABILITY_KEY
    if prob.nil? || (prob == 0)
      0.51
    else
      prob.round(2)
    end
  end

  def is_available_for_purchase(public_key)
    current_units = @game.get_player_time_units public_key
    current_units > 0
  end

  def get_multi(public_key)
    prob = get_bet_prob(public_key)
    
    multi = ((1/prob)*(1-HOUSE_EDGE)) - 1
    if multi < 0
      multi = 0
    end
    multi
end

  def random_gen
    r = Random.new
    gamble_value = r.rand * (MAX_WIN_PROB - MIN_WIN_PROB) + MIN_WIN_PROB

    gamble_value.round(2)
  end

  def win_or_lose(public_key)
    r = Random.new
    gamble_value = r.rand
    prob = get_bet_prob(public_key)

    if gamble_value < prob
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

      won_lose = win_or_lose(public_key)

      if won_lose
        @game.inc_time_units public_key, (bet_amount * (1 + get_multi(public_key)))
      end

      next_prob = random_gen
      @game.set_key_value public_key, BET_PROBABILITY_KEY, next_prob.to_s

    else
      puts "GET SOME UNITS"
    end
  end

  def action (public_key, dt)
  end
end
