require "../powerup.cr"
require "./cosmic_breakthrough"

class PowerupTediousGains < Powerup
  BASE_PRICE = BigFloat.new 10
  BASE_AMOUNT = BigFloat.new 0.1
  KEY = "tedious_gains_stack"

  def category
    PowerupCategory::PASSIVE
  end

  def self.get_powerup_id
    "tedious_gains"
  end

  def get_name
    "Von Neumann Probe"
  end

  def get_description (public_key)
    "Increases gains from Territorial Expanse by 10% with each purchase. Purchasing resets Territorial Expanses owned to 0.
    <br>Number of Territorial Expanses Needed: #{get_required_multi_price(public_key)}
    <br>Number of Von Neumann Probes: #{get_stack_size(public_key)}"
  end

  def is_stackable
    true
  end

  def get_required_multi_price(public_key)
    stack_size = (get_stack_size(public_key) ** 1.1) + 1
    price = BigFloat.new ( BASE_PRICE + (BASE_PRICE)  * ((stack_size/5)))
    price.round(0)
  end

  def get_price(public_key)
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage BASE_PRICE, BigFloat.new alterations.passive_price
  end

  def get_stack_size(public_key : String) : BigInt
    @game.get_key_value_as_int(public_key, KEY, BigInt.new 0)
  end

  def get_multi_stack(public_key)
    unit_multi = @game.get_powerup_classes[PowerupUnitMultiplier.get_powerup_id]
    unit_multi = unit_multi.as PowerupUnitMultiplier
    unit_multi.get_player_stack_size(public_key)
  end

  def get_unit_boost(public_key : String, base_amount : BigFloat) : BigFloat
    stack_size = get_stack_size(public_key)
    if stack_size == 0
      return base_amount
    end
    unit_boost = base_amount * ((stack_size * BASE_AMOUNT) + 1)

    unit_boost
  end

  def is_available_for_purchase(public_key)
    req = get_required_multi_price(public_key)
    multi_stack = get_multi_stack(public_key)
    if multi_stack >= req
      true
    else
      false
    end
  end

  def new_prestige(public_key, game : Game)
    game.set_key_value(public_key, KEY, (0).to_s)
  end

  def buy_action(public_key)
    if is_available_for_purchase(public_key)
        current_stack = get_stack_size(public_key)
        powerup = PowerupTediousGains.get_powerup_id

        @game.add_powerup(public_key, powerup)

        unit = @game.get_powerup_classes[PowerupUnitMultiplier.get_powerup_id]
        unit = unit.as PowerupUnitMultiplier
        unit.new_prestige(public_key, @game)

        new_stack = current_stack + 1
        @game.set_key_value(public_key, KEY, new_stack.to_s)

    else
      "You don't have enough units to purchase Unit Multiplier"
    end
  end

  def action(public_key, dt)
  end

  def cleanup(public_key)
  end
end
