require "../powerup.cr"
require "./cosmic_breakthrough"

class PowerupBoostSync < Powerup
  BASE_PRICE = BigFloat.new 43200.0
  DURATION = 10
  KEY_DURATION = "boost_sync_duration"
  KEY_PASSIVE_BOOSTS = "boost_sync_passive_boosts"

  def category
    PowerupCategory::ACTIVE
  end

  def self.get_powerup_id
    "boost_sync"
  end

  def get_name
    "Boost Sync"
  end

  def get_description(public_key)
    "<strong>Duration:</strong> #{DURATION} Seconds<br><strong>Stackable:</strong> No<br><strong>Toggleable:</strong> No<br>Enables passive effects during Overcharge"
  end

  def is_stackable
    false
  end

  def get_price(public_key)
    units_ps = BigFloat.new(@game.get_player_time_units_ps(public_key))
    purchased_passives_multi = BigFloat.new(calculate_passive_multiplier(public_key))

    price =  BigFloat.new((BASE_PRICE * units_ps * purchased_passives_multi))

    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage price, BigFloat.new alterations.active_price
  end

  def player_card_powerup_icon(public_key)
    "/boost_sync.png"
  end

  def get_popup_info(public_key) : PopupInfo
    pi = PopupInfo.new

    if !@game.get_key_value(public_key, KEY_DURATION).nil?
      durations = Array(Array(String)).from_json(@game.get_key_value public_key, KEY_DURATION)
      if !durations.empty?
        pi["Time Left"] = @game.format_time (force_big_int(durations[0][0]) - @game.ts)
      end
    end

    pi
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)

    (@game.has_powerup(public_key, PowerupOverCharge.get_powerup_id) &&  ((@game.get_player_time_units public_key) >= price))
  end

  # Method to calculate to overall unit generation boost from passives
  def calculate_passive_multiplier(public_key) : BigFloat
    unit_multiplier = get_unit_multiplier(public_key)
    compound_interest_boost = get_compound_interest_boost(public_key)

    total_multiplier = unit_multiplier * compound_interest_boost

    total_multiplier
  end

  # Helper method to get total multiplier from Unit Multiplier
  def get_unit_multiplier(public_key) : BigFloat
    unit_multi_powerup = @game.get_powerup_classes[PowerupUnitMultiplier.get_powerup_id]
    unit_multi_powerup = unit_multi_powerup.as PowerupUnitMultiplier
    stack_size = unit_multi_powerup.get_player_stack_size(public_key) + 1

    unit_multi_powerup.new_multiplier(public_key) * stack_size
  end

  # Helper method to get total current boost value from Compound Interest
  def get_compound_interest_boost(public_key) : BigFloat
    compound_powerup = @game.get_powerup_classes[PowerupCompoundInterest.get_powerup_id]
    compound_powerup = compound_powerup.as PowerupCompoundInterest
    compound_powerup.get_unit_boost(public_key)
  end

  def buy_action(public_key)
    if public_key
      if is_available_for_purchase(public_key) && @game.get_player_time_units(public_key) >= get_price(public_key)
        @game.set_player_time_units(public_key, (@game.get_player_time_units(public_key) - get_price(public_key)))

        durations = Array(Array(String)).new
        durations << [((@game.ts + DURATION).to_s), "1"]

        @game.set_key_value(public_key, KEY_DURATION, durations.to_json)
        @game.add_powerup(public_key, PowerupBoostSync.get_powerup_id)
        @game.add_active(public_key)

        puts "Purchased Boost Sync!"
      else
        puts "Cannot purchase Boost Sync"
      end
    else
      nil
    end
  end

  def action(public_key, dt)
    if @game.get_key_value(public_key, KEY_DURATION)
      # Dynamically calculate passive multiplier each time action runs
      passive_multiplier = calculate_passive_multiplier(public_key)

      # Apply passive boost
      unit_rate = BigFloat.new(@game.get_player_time_units_ps(public_key))
      boost_rate = (unit_rate * passive_multiplier) - unit_rate

      @game.inc_time_units_ps(public_key, boost_rate)
    end
  end

  def cleanup(public_key)
    if public_key
      if !@game.get_key_value(public_key, KEY_DURATION).nil?
        durations = Array(Array(String)).from_json(@game.get_key_value public_key, KEY_DURATION)

        if !durations.nil? && !durations.empty?
          duration = force_big_int(durations[0][0])
          current_time = @game.ts

          if duration <= current_time
            durations.delete_at(0)

            if durations.empty?
              @game.set_key_value(public_key, KEY_DURATION, "")
              @game.remove_powerup(public_key, PowerupBoostSync.get_powerup_id)
            else
              @game.set_key_value(public_key, KEY_DURATION, durations.to_json)
            end
          end
        end
      end
    end
  end
end
