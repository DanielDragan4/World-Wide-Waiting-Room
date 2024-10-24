require "../powerup"

class PowerupBootStrap < Powerup
  STACK_KEY = "bootstrap_stack"
  COOLDOWN_KEY = "bootstrap_cooldown"
  BASEPRICE = 5000
  BASEBURST = 0.05

  def new_baseburst(public_key) : Float64
    get_synergy_boosted_multiplier(public_key, BASEBURST)
  end

  def self.get_powerup_id
    "bootstrap"
  end

  def get_name
    "BootStrap"
  end

  def is_stackable
    true
  end

  def get_description(public_key)
    new_baseburst = new_baseburst(public_key)
    "Gives #{(new_baseburst * 100).round}% of total units Increasing multiplictivly with each purchase. Can only be purchased once every 24 hours. Cost of 5000 + 10% of your total units.\nNext Amount Earned: #{(1 + (new_baseburst * get_player_stack_size(public_key))).round(2)}x points"
  end

  def get_price (public_key)
    price = (BASEPRICE + ((@game.get_player_time_units public_key) * 0.1)).round(2)
  end

  def max_stack_size (public_key)
    7.0
  end

  def is_available_for_purchase(public_key)
    if public_key
      cooldown = @game.get_player_cooldown(public_key, COOLDOWN_KEY)

      return cooldown
    else
      false
    end
  end

  def get_player_stack_size(public_key)
    if public_key
      size = @game.get_key_value(public_key, STACK_KEY)
      size.to_s.empty? ? 1 : size.to_i
    else
      1
    end
  end

  def buy_action (public_key)

    if public_key
      if is_available_for_purchase(public_key)

        current_stack = get_player_stack_size(public_key)

        puts "Purhcased Burst Boost!"
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) * 0.9)
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) * (1 + (new_baseburst(public_key) * current_stack)))
        @game.set_key_value(public_key, COOLDOWN_KEY, (@game.ts + 86400).to_s)

        new_stack = current_stack + 1
        @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)
      else
        puts "Your out of BootStraps today :(. Come back tommorow for another!"
      end
    else
      nil
    end
    nil
  end

  def action (public_key, dt)
  end
end
