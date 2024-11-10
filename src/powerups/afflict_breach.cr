require "../powerup"
require "json"

require "./unit_multiplier"
require "./compound_interest.cr"
require "./force_field.cr"

class AfflictPowerupBreach < Powerup
  COOLDOWN = BigFloat.new 60 * 10
  COOLDOWN_KEY = "afflict_signal_jammer_cooldown"

  def self.get_powerup_id
    "afflict_breach"
  end

  def get_name
    "Breach"
  end

  def get_popup_info (public_key)
    pi = PopupInfo.new
    pi["Time Left"] = (@game.get_timer_seconds_left public_key, COOLDOWN_KEY)
    pi
  end

  def player_card_powerup_icon (public_key)
    "/breach.png"
  end

  def is_afflication_powerup (public_key)
    true
  end

  def get_cooldown_time (public_key)
    get_synergy_boosted_multiplier public_key, COOLDOWN
  end

  def is_available_for_purchase (public_key)
    false
  end

  def buy_action (public_key)
    if @game.has_powerup public_key, PowerupForceField.get_powerup_id
      return
    end

    @game.add_powerup public_key, AfflictPowerupBreach.get_powerup_id
    @game.set_timer public_key, COOLDOWN_KEY, (get_cooldown_time public_key).to_i64
  end

  def action (public_key, dt)
    puts "Afflict Breach action run for #{public_key} #{@game.get_timer_seconds_left public_key, COOLDOWN_KEY}"
  end

  def cleanup (public_key)
    @game.remove_powerup_if_timer_expired public_key, COOLDOWN_KEY, AfflictPowerupBreach.get_powerup_id
  end
end
