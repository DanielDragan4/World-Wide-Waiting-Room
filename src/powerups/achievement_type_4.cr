require "../powerup"

class AchievementTypeIV < Powerup
  UNITS_MILESTONE = BigFloat.new (4 * 10e46)
  UPS_BOOST = BigFloat.new 100_000

  def self.get_powerup_id
    "achievement_type_4"
  end

  def get_name
    "Type IV Civilization"
  end

  def get_description (public_key)
    "Gives a permanent 100,000 units/s boost."
  end

  def get_price (public_key : String)
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage(UNITS_MILESTONE, BigFloat.new(alterations.achievement_goal))
  end

  def is_achievement_powerup (public_key)
    true
  end

  def action (public_key, dt)
    pu_id = AchievementTypeIV.get_powerup_id
    if !(@game.has_powerup public_key, pu_id)
      tu = @game.get_player_time_units public_key
      if tu >= get_price public_key
        @game.add_powerup public_key, pu_id
        @game.send_animation_event public_key, Animation::NUMBER_FLOAT, { "value" => "Type IV Civilization Achieved", "color" => "#05FF05" }
      end
    else
      @game.inc_time_units_ps public_key, UPS_BOOST
    end
  end
end
