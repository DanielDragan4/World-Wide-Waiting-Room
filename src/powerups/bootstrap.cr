require "../powerup"

class PowerupBootStrap < Powerup
  STACK_KEY = "bootstrap_stack"
  COOLDOWN_KEY = "bootstrap_cooldown"
  COOLDOWN_TIME = 60 * 60 * 6
  BASEPRICE = BigFloat.new 5000
  COST_PERCENTAGE = 0.15
  BASE_PERCENT_INCREASE = BigFloat.new 0.05

  def category
    PowerupCategory::ACTIVE
  end

  def self.get_powerup_id
    "bootstrap"
  end

  def get_name
    "Terraform"
  end

  def is_stackable
    true
  end

  def percent_increase(public_key)
    (get_player_stack_size public_key) * BASE_PERCENT_INCREASE
  end

  def new_base_percent_increase(public_key) : BigFloat
    precentage = get_synergy_boosted_multiplier(public_key, (percent_increase public_key))

    if precentage > 5
      precentage = 5.0
      precentage = BigFloat.new precentage
    end
    precentage
  end

  def next_units_inc (public_key)
    new_base_pi = new_base_percent_increase public_key
    ((@game.get_player_time_units public_key) * (new_base_pi ** 2))
  end


  def get_description(public_key)
    new_base_pi = new_base_percent_increase(public_key)
    "Gives <b>#{(new_base_pi * 100).round}%</b> of your total Units. This percentage increases exponentially with each purchase. The cost of is <b>#{BASEPRICE} + #{COST_PERCENTAGE * 100}%</b> of your total units. This powerup can be purchased once every <b>six hours</b>."
  end

  def cooldown_seconds_left(public_key) : Int32
    @game.get_timer_seconds_left public_key, COOLDOWN_KEY
  end

  def get_price (public_key)
    price = (BASEPRICE + (@game.get_player_time_units public_key) * (COST_PERCENTAGE ** 1.5)).round(2)
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage price, BigFloat.new alterations.active_price
  end

  def is_available_for_purchase(public_key)
    current_units = @game.get_player_time_units public_key
    (@game.is_timer_expired public_key, COOLDOWN_KEY) && ((get_price public_key) <= current_units)
  end

  def get_player_stack_size(public_key)
    @game.get_key_value_as_int(public_key, STACK_KEY, BigInt.new 1)
  end

  def buy_action (public_key)
    if is_available_for_purchase(public_key)
      puts "Purchased Burst Boost!"

      next_inc = (next_units_inc public_key)

      @game.inc_time_units public_key, -(get_price public_key) + next_inc
      @game.set_timer public_key, COOLDOWN_KEY, COOLDOWN_TIME
      @game.add_active public_key

      new_stack = (get_player_stack_size public_key) + 1
      @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)
    else
      puts "Your out of Terraforms today :(. Come back tommorow for another!"
    end
  end

  def action (public_key, dt)
  end
end
