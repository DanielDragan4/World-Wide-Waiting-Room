require "../powerup.cr"
require "./unit_multiplier"
require "./synergy_matrix"


class PowerupCosmicBreak < Powerup
  KEY = "cosmic_break_stack"
  SYNERGY_VALUES = [1.0, 2.5, 4.0, 6.0, 8.0, 10.0, 0]
  UNIT_VALUES = [1.0, 5.0, 15.0, 30.0, 50.0, 75.0, 0]
  PRICES = [4e12, 4e27, 4e38, 4e47, 4e58, 0]

  def get_stack_size(public_key : String) : BigInt
    @game.get_key_value_as_int(public_key, KEY, BigInt.new 0)
  end

  def get_unit_boost(public_key : String, base_amount : BigFloat) : BigFloat
    stack_size = get_stack_size(public_key)
    unit_boost = UNIT_VALUES[stack_size] * base_amount

    unit_boost
  end

  def get_synergy_boost(public_key : String, base_amount : BigFloat) : BigFloat

    stack_size = get_stack_size(public_key)
    synergy_boost = SYNERGY_VALUES[stack_size] * base_amount

    synergy_boost
  end

  def self.get_powerup_id
    "cosmic_breakthrough"
  end

  def get_name
    "Cosmic Breakthrough"
  end

  def get_description(public_key)
    stack_size = get_stack_size(public_key)
    "Resets Territorial Expanse, Synergy Matrix, Automation Upgrade, and von Neumann probe to 0 but increases their base rate by some multiple. Requires getting the designated Type Achievement before each purchase, <br> Current Civi Type: #{stack_size} <br> Next Synergy Precent: #{SYNERGY_VALUES[stack_size+1]*10}% <br> Next Territorial Expanse Rate: #{UNIT_VALUES[stack_size+1]}"
  end

  def category
    PowerupCategory::PASSIVE
  end

  def get_price(public_key)
    stack_size = get_stack_size(public_key)
    price = BigFloat.new PRICES[stack_size]
    alterations = @game.get_cached_alterations

    @game.increase_number_by_percentage price, BigFloat.new alterations.passive_price
  end

  def is_available_for_purchase(public_key)
    stack_size = get_stack_size(public_key)
    price = get_price(public_key)
    units = @game.get_player_time_units(public_key)

    pu_id = [AchievementTypeI.get_powerup_id, AchievementTypeII.get_powerup_id, AchievementTypeIII.get_powerup_id, AchievementTypeIV.get_powerup_id, AchievementTypeV.get_powerup_id]

    available = (units > price) && (stack_size < 5) && (@game.has_powerup public_key, pu_id[stack_size])
    available
  end

  def buy_action(public_key)
    puts "Purchasing Cosmic Breakthrough"
    if public_key
      price = get_price(public_key)

      if is_available_for_purchase(public_key)
        current_stack = get_stack_size(public_key)
        new_stack = current_stack + 1
        
        @game.inc_time_units(public_key, -price)
        @game.set_key_value(public_key, KEY, new_stack.to_s)
        @game.add_powerup(public_key, PowerupCosmicBreak.get_powerup_id)

        synergy = @game.get_powerup_classes[PowerupSynergyMatrix.get_powerup_id]
        unit = @game.get_powerup_classes[PowerupUnitMultiplier.get_powerup_id]
        automation = @game.get_powerup_classes[PowerupAutomationUpgrade.get_powerup_id]
        tedious = @game.get_powerup_classes[PowerupTediousGains.get_powerup_id]

        synergy = synergy.as PowerupSynergyMatrix
        unit = unit.as PowerupUnitMultiplier
        automation = automation.as PowerupAutomationUpgrade
        tedious = tedious.as PowerupTediousGains

        synergy.new_prestige(public_key, @game)
        unit.new_prestige(public_key, @game)
        automation.new_prestige(public_key, @game)
        tedious.new_prestige(public_key, @game)
      else
        return "Not enough time units"
      end
    end
  end

  def action(public_key, dt)
  end

  def cleanup(public_key)
  end
end
