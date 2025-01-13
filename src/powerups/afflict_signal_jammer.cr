require "../powerup"
require "./force_field.cr"

class AfflictPowerupSignalJammer < Powerup
  COOLDOWN = BigFloat.new 60 * 10
  UPS_PERCENT_DECREASE = BigFloat.new 0.5
  AMOUNT_DEC_KEY = "afflict_signal_jammer_tups_diff"
  COOLDOWN_KEY = "afflict_signal_jammer_cooldown"

  def get_name
    "Signal Jammer"
  end

  def self.get_powerup_id
    "afflict_signal_jammer"
  end

  def is_afflication_powerup (public_key)
    true
  end

  def get_popup_info (public_key)
    pi = PopupInfo.new
    pi["Time Left"] = (@game.get_timer_time_left public_key, COOLDOWN_KEY)
    pi
  end

  def is_available_for_purchase (public_key)
    false
  end

  def player_card_powerup_icon (public_key)
    "/jam.png"
  end

  def get_cooldown_time (public_key)
    afflictor = @game.get_key_value(public_key, "afflict_signal_jammer_afflicted_by")
    multi = (get_synergy_boosted_multiplier afflictor, BigFloat.new 1.0) -1
    reduced_multi = multi/10

    COOLDOWN * (1 + reduced_multi)
  end

  def buy_action (public_key)
    @game.add_powerup public_key, AfflictPowerupSignalJammer.get_powerup_id
    @game.set_timer public_key, COOLDOWN_KEY, (get_cooldown_time(public_key)).to_i64
  end

  def action (public_key, dt)
    if @game.has_powerup public_key, PowerupForceField.get_powerup_id
      return
    end

    puts "Afflict Signal Jammer action run for #{public_key} #{@game.get_timer_seconds_left public_key, COOLDOWN_KEY}"

    player_tups = @game.get_player_time_units_ps public_key
    amount_dec = player_tups * UPS_PERCENT_DECREASE

    @game.inc_time_units_ps public_key, -amount_dec
  end

  def cleanup (public_key)
    @game.remove_powerup_if_timer_expired public_key, COOLDOWN_KEY, AfflictPowerupSignalJammer.get_powerup_id
  end
end
