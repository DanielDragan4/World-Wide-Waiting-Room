require "../powerup"
require "./force_field.cr"

class AfflictPowerupSignalJammer < Powerup
  COOLDOWN = 60 * 60 * 10
  UPS_PERCENT_DECREASE = 0.5
  AMOUNT_DEC_KEY = "afflict_signal_jammer_tups_diff"
  COOLDOWN_KEY = "afflict_signal_jammer_cooldown"

  def self.get_powerup_id
    "afflict_signal_jammer"
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
    @game.add_powerup public_key, AfflictPowerupSignalJammer.get_powerup_id
    @game.set_timer public_key, COOLDOWN_KEY, COOLDOWN
  end

  def action (public_key, dt)
    if @game.has_powerup public_key, PowerupForceField.get_powerup_id
      return
    end

    player_tups = @game.get_player_time_units_ps public_key
    amount_dec = player_tups * UPS_PERCENT_DECREASE

    @game.set_key_value public_key, AMOUNT_DEC_KEY, amount_dec.to_s
    @game.inc_time_units_ps public_key, -amount_dec
  end

  def cleanup (public_key)
    amount_dec = @game.get_key_value_as_float public_key, AMOUNT_DEC_KEY
    @game.inc_time_units_ps public_key, amount_dec
    @game.remove_powerup_if_timer_expired public_key, COOLDOWN_KEY, AfflictPowerupSignalJammer.get_powerup_id
  end
end
