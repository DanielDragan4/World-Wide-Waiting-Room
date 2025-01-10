require "../powerup.cr"

class PowerupCompoundInterest < Powerup
  BASE_PRICE = BigFloat.new 1000.0
  KEY = "compound_interest_purchased"
  BOOST_COUNT_KEY = "compound_interest_boost_count"
  USED_MILESTONES_KEY = "compound_interest_used_milestones"
  BOOST_MULTIPLIER = BigFloat.new 0.1
  BOOST_DURATION = 600
  KEY_DURATION = "compound_interest_durations"
  INITIAL_MILESTONE = BigFloat.new 1000.0

  def category
    PowerupCategory::PASSIVE
  end

  def new_multiplier(public_key) : BigFloat
    get_synergy_boosted_multiplier(public_key, BOOST_MULTIPLIER)
  end

  def self.get_powerup_id
    "compound_interest"
  end

  def get_name
    "Compound Interest"
  end

  def player_card_powerup_icon (public_key)
    "/compound-interest.png"
  end

  def get_popup_info(public_key) : PopupInfo
    durations_json = @game.get_key_value(public_key, KEY_DURATION) || "[]"
    durations = Array(Array(String)).from_json(durations_json)
    boost_count = get_stored_boost_count(public_key)

    pi = PopupInfo.new
    if durations.any?
      time_left = (BigFloat.new(durations[0][0]) - @game.ts).to_s
      pi["Time Left"] = time_left
    else
      pi["Time Left"] = "No active boosts"
    end

    active_boosts_count = durations.count { |duration| BigFloat.new(duration[0]) > @game.ts }

    if active_boosts_count > 0
      pi["Active Boosts"] = active_boosts_count.to_s
    end

    pi["Stored Boosts"] = boost_count.to_s
    pi
  end

  def get_description(public_key)
    next_milestone = BigFloat.new(get_next_milestone(public_key))
    boost_count = get_stored_boost_count(public_key)
    boost_multiplier = (new_multiplier(public_key) * 100).round
    if !is_purchased(public_key)
    "Earn a 10 minute #{boost_multiplier}% production boost for each new milestone reached (one-time use). Next milestone: #{format_milestone(next_milestone)} units.<br>"
    else
    "Earn a 10 minute #{boost_multiplier}% production boost for each new milestone reached (one-time use). Next milestone: #{format_milestone(next_milestone)} units.<br>
    Stored boosts: #{boost_count}<br>
    (Purchase again to use stored boosts)"
    end
  end

  def is_stackable
    false
  end

  def get_price(public_key)
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage BASE_PRICE, BigFloat.new alterations.passive_price
  end

  def is_available_for_purchase(public_key)
    if is_purchased(public_key)
      if get_stored_boost_count(public_key) == 0
        return false
      end
    else
      if @game.get_player_time_units(public_key) < get_price(public_key)
        return false
      end
    end

    return true
  end

  def is_purchased(public_key)
    @game.get_key_value(public_key, KEY) == "true"
  end

  def get_stored_boost_count(public_key : String)
    @game.get_key_value_as_int(public_key, BOOST_COUNT_KEY, BigInt.new 0)
  end

  def format_milestone(milestone : BigFloat) : String
    if milestone < 1_000_000_000.0
      format_with_commas(milestone)
    else
      format_in_scientific_notation(milestone)
    end
  end

  # Helper method to format numbers with commas
  def format_with_commas(value : BigFloat) : String
    integer_part, decimal_part = value.to_s.split(".")
    # Insert commas into the integer part, every 3 digits
    integer_part = integer_part.reverse.chars.each_slice(3).map(&.join).join(",").reverse
    decimal_part ? "#{integer_part}.#{decimal_part}" : integer_part
  end

  # Helper method to format numbers in scientific notation
  def format_in_scientific_notation(value : BigFloat) : String
    exponent = Math.log10(value).floor
    base = value / (10.0 ** exponent)
    "#{base.round(2)} x 10^#{exponent}"
  end

  # Returns all milestone values the player has already reached
  def get_used_milestones(public_key : String) : Set(BigFloat)
    used_milestones_str = @game.get_key_value(public_key, USED_MILESTONES_KEY) || ""
    used_milestones_str.empty? ? Set(BigFloat).new : used_milestones_str.split(",").map(&.to_big_f).to_set
  end

  # Returns value of the next milestone the player can reach
  def get_next_milestone(public_key)
    milestone = INITIAL_MILESTONE
    used_milestones = get_used_milestones(public_key)

    while used_milestones.includes?(milestone)
      milestone *= 10.0
    end
    milestone
  end

  # Calculates number of boosts that should be given at time of purchase based on player's current total units
  # Inserts reached milestone values into set as already being reached
  def calculate_retroactive_boosts(public_key : String) : BigInt
    units = @game.get_player_time_units(public_key)
    used_milestones = get_used_milestones(public_key)
    milestone = BigFloat.new(INITIAL_MILESTONE)
    retroactive_boosts = BigInt.new 0

    while units >= milestone
      unless used_milestones.includes?(milestone)
        retroactive_boosts += 1
        used_milestones.add(milestone)
      end
      milestone *= 10.0
    end

    @game.set_key_value(public_key, USED_MILESTONES_KEY, used_milestones.map(&.to_s).join(","))
    retroactive_boosts
  end

  # If powerup not purchased: initializes all keys and provides retroactive boosts for milestones instantly complete
  # If powerup is purchased: clicking "Buy" button again uses all boosts in storage
  def buy_action(public_key)
    if !is_purchased(public_key)
      puts "Purchasing Compound Interest"
      @game.add_powerup public_key, PowerupCompoundInterest.get_powerup_id
      @game.inc_time_units(public_key, -BASE_PRICE)
      @game.set_key_value(public_key, KEY, "true")
      @game.set_key_value(public_key, BOOST_COUNT_KEY, "0")
      @game.set_key_value(public_key, USED_MILESTONES_KEY, "")
      @game.set_key_value(public_key, KEY_DURATION, "[]")

      #Calls calculate_retroactive_boosts to give boosts for milestones that were instantly complete
      retroactive_boosts = calculate_retroactive_boosts(public_key)
      @game.set_key_value(public_key, BOOST_COUNT_KEY, retroactive_boosts.to_s)
      puts "Stored #{retroactive_boosts} retroactive boosts!"
    else
      # Retrieves number of stored boosts and uses them. Sets stored boosts to 0.
      # If no boosts, return message saying no boosts are in storage
      stored_boosts = get_stored_boost_count(public_key)
      if stored_boosts > 0
        puts "stored boosts: #{stored_boosts}"
        apply_stored_boosts(public_key, stored_boosts)
        @game.set_key_value(public_key, BOOST_COUNT_KEY, "0")
        puts "Claimed #{stored_boosts} production boosts!"
      else
        puts "No stored boosts available to claim."
      end
    end
  end

  # Applies all stored boosts by adding entries to KEY_DURATION list [boost duration, multiplier value]
  # Currently multipliers are additive and all identical values
  def apply_stored_boosts(public_key : String, boost_count : BigInt)
    durations_json = @game.get_key_value(public_key, KEY_DURATION) || "[]"
    durations = Array(Array(String)).from_json(durations_json)

    # Stores full multiplier (ex 1.1) not just the boost (ex 0.1)
    boost_multiplier = 1.0 + new_multiplier(public_key)

    boost_count.times do
      durations << [((@game.ts + BOOST_DURATION).to_s), boost_multiplier.to_s]
    end

    puts "Adding #{boost_count} boosts with multiplier #{boost_multiplier}"
    @game.set_key_value(public_key, KEY_DURATION, durations.to_json)
  end

  # Returns total multiplier for all currently active boosts
  def get_unit_boost(public_key)
    return BigFloat.new 1.0 unless is_purchased(public_key)

    durations_json = @game.get_key_value(public_key, KEY_DURATION) || "[]"
    durations = Array(Array(String)).from_json(durations_json)
    boost_units = BigFloat.new 1.0

    # Stacks boost values additively
    durations.each do |t|
      if force_big_int(t[0]) > @game.ts
        boost_units += BigFloat.new(t[1]) - 1
      end
    end

    boost_units
  end

  # Checks if next milestone has been reached. If yes, adds boost to storage.
  # Applies any active boosts.
  def action(public_key, dt)
    return unless is_purchased(public_key)

    # Checks for new milestones
    units = @game.get_player_time_units(public_key)
    used_milestones = get_used_milestones(public_key)
    boost_count = get_stored_boost_count(public_key)

    # Loop through all milestones up to the current unit amount and apply boosts
    milestone = BigFloat.new(INITIAL_MILESTONE)
    new_boosts = 0

    # Iterate over all new milestones (in case of instant unit gain) and add them
    while units >= milestone
      unless used_milestones.includes?(milestone)
        new_boosts += 1
        used_milestones.add(milestone)
      end
      milestone *= 10.0
    end

    # Updates stored boost count and used milestones if any boosts were added
    if new_boosts > 0
      boost_count += new_boosts
      @game.set_key_value(public_key, BOOST_COUNT_KEY, boost_count.to_s)
      @game.set_key_value(public_key, USED_MILESTONES_KEY, used_milestones.to_a.join(","))
      puts "Milestones reached! Added #{new_boosts} new boosts, for a total of #{boost_count} stored boosts."
    end

    # Applies any active boosts if no "blocking" powerups applied
    if !(@game.has_powerup(public_key, PowerupHarvest.get_powerup_id)) && !(@game.has_powerup(public_key, PowerupOverCharge.get_powerup_id)) && (!(@game.has_powerup(public_key, AfflictPowerupBreach.get_powerup_id)) || (@game.has_powerup(public_key, PowerupForceField.get_powerup_id)))
      unit_rate = @game.get_player_time_units_ps(public_key)
      boost_multiplier = get_unit_boost(public_key)
      boost_amount = (unit_rate * boost_multiplier) - unit_rate

      if boost_amount > 0
        puts "Applying boost: multiplier = #{boost_multiplier}"
        @game.inc_time_units_ps(public_key, boost_amount)
      end
    end
  end

  # Removes any expired boosts from KEY_DURATION list
  def cleanup(public_key)
    return unless is_purchased(public_key)

    durations_json = @game.get_key_value(public_key, KEY_DURATION) || "[]"
    durations = Array(Array(String)).from_json(durations_json)

    active_before = durations.count { |d| force_big_int(d[0]) > @game.ts }
    durations.reject! { |duration| force_big_int(duration[0]) <= @game.ts }
    active_after = durations.size

    if active_before != active_after
      puts "Cleanup: Removed #{active_before - active_after} expired boosts. #{active_after} boosts remaining."
    end

    @game.set_key_value(public_key, KEY_DURATION, durations.to_json)
  end
end
