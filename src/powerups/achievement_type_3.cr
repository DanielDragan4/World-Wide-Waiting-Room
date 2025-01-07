require "../powerup"

class AchievementTypeIII < Powerup
  UNITS_MILESTONE = BigFloat.new (4 * 10e37)
  UPS_BOOST = BigFloat.new 10_000

  def self.get_powerup_id
    "achievement_type_3"
  end

  def get_name
    "Type III Civilization"
  end

  def get_description (public_key)
    "Gives a permanent 10,000 units/s boost."
  end

  def get_price (public_key : String)
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage(UNITS_MILESTONE, BigFloat.new(alterations.achievement_goal))
  end

  def is_achievement_powerup (public_key)
    true
  end

  def action (public_key, dt)
    alterations = @game.get_cached_alterations
    pu_id = AchievementTypeIII.get_powerup_id
    if !(@game.has_powerup public_key, pu_id)
      tu = @game.get_player_time_units public_key
      if tu >= get_price public_key
        @game.add_powerup public_key, pu_id
        @game.send_animation_event public_key, Animation::NUMBER_FLOAT, { "value" => "Type III Civilization Achieved", "color" => "#05FF05" }
      end
    else
      @game.inc_time_units_ps public_key, UPS_BOOST
    end
  end
end
