require "../powerup"
require "json"

require "./unit_multiplier"

class AfflictPowerupBreach < Powerup
  COOLDOWN = 60 * 60 * 10
  COOLDOWN_KEY = "afflict_signal_jammer_cooldown"
  BREACH_POWERUPS_OWNED_KEY = "afflict_breah_powerups_owned"

  # Should change this with a higher level @game.get_passive_powerups
  PASSIVE_POWERUP_IDS = [
    PowerupUnitMultiplier.get_powerup_id
  ]

  def self.get_powerup_id
    "afflict_breach"
  end

  def is_afflication_powerup (public_key)
    true
  end

  def is_available_for_purchase (public_key)
    false
  end

  def get_cooldown_seconds_left (public_key)
    @game.get_timer_seconds_left public_key, COOLDOWN_KEY
  end

  def buy_action (public_key)
    @game.add_powerup public_key, AfflictPowerupBreach.get_powerup_id
    @game.set_timer public_key, COOLDOWN_KEY, COOLDOWN
  end

  def action (public_key, dt)
    owned_powerups = PASSIVE_POWERUP_IDS.reject do |p|
      !@game.has_powerup public_key, p
    end

    @game.set_key_value public_key, BREACH_POWERUPS_OWNED_KEY, owned_powerups.to_json
  end

  def cleanup (public_key)
    if @game.is_timer_expired public_key, COOLDOWN_KEY
      @game.remove_powerup public_key, AfflictPowerupBreach.get_powerup_id
      saved_powerups = @game.get_key_value public_key, BREACH_POWERUPS_OWNED_KEY
      if saved_powerups
        pu_array = Array(String).from_json saved_powerups
        pu_array.each do |p|
          @game.add_powerup public_key, p
        end
      end
    end
  end
end
