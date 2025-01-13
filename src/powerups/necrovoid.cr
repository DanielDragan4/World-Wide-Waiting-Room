require "../powerup.cr"

class PowerupNecrovoid < Powerup
  BASE_PRICE = BigFloat.new 0.0
  COOLDOWN_KEY = "necrovoider_timer"
  DURATION = 60 * 60 * 12
  PRODUCTION_HIT = BigFloat.new 0.10

  def self.get_powerup_id
    "necrovoid"
  end

  def get_name
    "Necrovoid"
  end

  def get_description(public_key)
    player_ups = @game.get_player_frame_ups public_key
    projected_ups = @game.format_units (@game.increase_number_by_percentage player_ups, -PRODUCTION_HIT * 100).round(2)

    percentage = (PRODUCTION_HIT * 100).round(2)

    active_inactive = "Disabled"

    if @game.has_powerup public_key, PowerupNecrovoid.get_powerup_id
      active_inactive = "Enabled"
    end

    bottom = <<-D
    Your character remains in-game for 12 hours even if you go offline.
    Purchasing Necrovoid while it is active removes the effect.
    D


    if active_inactive == "Disabled"
      <<-D
      <strong>Status: #{active_inactive}</strong><br>
      <strong>Duration: #{@game.format_time DURATION}</strong><br>
      <strong>-#{percentage}% Unit/s (#{projected_ups})</strong><br>
      <br>
      #{bottom}
      D
    else
      time_left = @game.get_timer_time_left public_key, COOLDOWN_KEY
      <<-D
      <strong>Status: #{active_inactive}</strong><br>
      <strong>Time Remaining: #{time_left}</strong>
      <br>
      #{bottom}
      D
    end
  end

  def get_duration_time (public_key)
    multi = (get_synergy_boosted_multiplier public_key, BigFloat.new 1.0) - 1
    reduced_multi = multi/10

    (DURATION * (1 + reduced_multi)).to_i
  end

  def category
    PowerupCategory::PASSIVE
  end

  def is_stackable
    false
  end

  def get_popup_info(public_key) : PopupInfo
    pi = PopupInfo.new

    currently_online = "No"

    if @game.is_player_online public_key
      currently_online = "Yes"
    end

    pi["Time Left"] = @game.get_timer_time_left public_key, COOLDOWN_KEY
    pi["Currently Online"] = currently_online
    pi
  end

  def player_card_powerup_icon (public_key)
    "/necrovoid.png"
  end

  def get_price (public_key : String) : BigFloat
    BASE_PRICE
  end

  def buy_action(public_key)
    if @game.has_powerup public_key, PowerupNecrovoid.get_powerup_id
      @game.remove_necrovoider public_key
      @game.remove_powerup public_key, PowerupNecrovoid.get_powerup_id
    else
      adjusted_duration = get_duration_time(public_key)
      @game.add_powerup public_key, PowerupNecrovoid.get_powerup_id
      @game.set_timer public_key, COOLDOWN_KEY, adjusted_duration
      @game.add_necrovoider public_key
    end
  end

  def is_available_for_purchase(public_key)
    true
  end

  def action(public_key : String, dt)
    amount_dec = (@game.get_player_time_units_ps public_key) * PRODUCTION_HIT
    @game.inc_time_units_ps public_key, -amount_dec
  end

  def cleanup(public_key : String)
    if @game.is_timer_expired public_key, COOLDOWN_KEY
      @game.remove_necrovoider public_key
      @game.remove_powerup public_key, PowerupNecrovoid.get_powerup_id
    end
  end
end
