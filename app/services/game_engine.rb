class GameEngine
  def self.start_run(starting_prompt)
    run = Run.create!(starting_prompt: starting_prompt, status: "active")

    # 1. Generate Character profile via Gemini
    profile = GeminiClient.generate_character(starting_prompt)

    # 2. Create the Character in DB
    character = Character.create!(
      run: run,
      first_name: profile["first_name"] || "John",
      last_name: profile["last_name"] || "Doe",
      age: profile["age"] || 18,
      location: profile["location"] || "Paris, France",
      occupation: profile["occupation"] || "Sans emploi",
      cash: profile["cash"] || 1000,
      health: sanitize_stat(profile["health"] || 90),
      happiness: sanitize_stat(profile["happiness"] || 70),
      intelligence: sanitize_stat(profile["intelligence"] || 60),
      fitness: sanitize_stat(profile["fitness"] || 50),
      looks: sanitize_stat(profile["looks"] || 50),
      charisma: sanitize_stat(profile["charisma"] || 50),
      relationships: profile["relationships"] || {},
      assets: []
    )

    # 3. Create the starting LifeEvent (the introduction)
    LifeEvent.create!(
      run: run,
      age: character.age,
      icon_type: "sparkles",
      title: "Le Commencement",
      narrative: profile["starting_story"] || "Votre histoire commence ici.",
      choices: [
        { "id" => "start", "text" => "Faire vos premiers pas", "risk" => "none", "preview" => "Commencer l'aventure" }
      ]
    )

    run
  end

  def self.play_turn(character, choice_id: nil, custom_action: nil)
    run = character.run
    return if run.status != "active"

    # 1. Find the active event (the current one needing response)
    last_event = run.life_events.order(id: :asc).last
    return unless last_event

    # 2. Extract action text
    action_text = ""
    if custom_action.present?
      action_text = custom_action
    elsif choice_id.present?
      choice = last_event.choices.find { |c| c["id"] == choice_id }
      action_text = choice ? choice["text"] : choice_id
    else
      action_text = "Laisser le destin décider."
    end

    # 3. Get recent resolved history for LLM context, excluding the active placeholder.
    history = run.life_events.where.not(id: last_event.id).order(id: :desc).limit(5).to_a.reverse

    # 4. Ask Gemini for the Game Master reply.
    response = GeminiClient.resolve_turn(character, last_event, action_text, history) || {}

    # 5. Process resolution and update character stats
    reply = response["reply"] || "Vous continuez votre route."
    proposed = response["proposed_changes"] || {}
    age_delta = sanitize_age_delta(response["age_delta"])

    # Update stats safely
    character.cash += stat_delta(proposed, "cash_delta")
    character.health = sanitize_stat(character.health + stat_delta(proposed, "health"))
    character.happiness = sanitize_stat(character.happiness + stat_delta(proposed, "happiness"))
    character.intelligence = sanitize_stat(character.intelligence + stat_delta(proposed, "intelligence"))
    character.fitness = sanitize_stat(character.fitness + stat_delta(proposed, "fitness"))
    character.looks = sanitize_stat(character.looks + stat_delta(proposed, "looks"))
    character.charisma = sanitize_stat(character.charisma + stat_delta(proposed, "charisma"))

    # Update relationships
    if proposed["relationships"]
      proposed["relationships"].each do |name, val|
        current_val = character.relationships[name] || 50
        character.relationships[name] = sanitize_stat(current_val + val.to_i)
      end
    end

    # Add new relationships
    if response["new_relationships"]
      response["new_relationships"].each do |rel|
        name_key = "#{rel['name']} (#{rel['role']})"
        character.relationships[name_key] = sanitize_stat(rel["value"] || 50)
      end
    end

    # Remove relationships
    if response["removed_relationships"]
      response["removed_relationships"].each do |name|
        character.relationships.delete(name)
      end
    end

    # Manage assets
    if response["new_assets"]
      character.assets = (character.assets + response["new_assets"]).uniq
    end
    if response["removed_assets"]
      character.assets = character.assets - response["removed_assets"]
    end

    # Save resolution details and stat deltas to the event
    last_event.update!(
      selected_choice_id: choice_id,
      player_custom_action: action_text,
      resolution_narrative: reply,
      applied_changes: proposed
    )

    character.age += age_delta

    # 6. Apply deterministic game over rules
    if character.health <= 0
      run.update!(status: "dead")
      # Create final death card
      LifeEvent.create!(
        run: run,
        age: character.age,
        icon_type: "skull",
        title: "Fin de Vie",
        narrative: "Vous vous éteignez à l'âge de #{character.age} ans. Votre santé a atteint le point critique.",
        choices: []
      )
    elsif character.age >= 100
      run.update!(status: "retired")
      LifeEvent.create!(
        run: run,
        age: character.age,
        icon_type: "info",
        title: "Retraite méritée",
        narrative: "À l'âge vénérable de 100 ans, vous décidez de vous retirer paisiblement de la vie active.",
        choices: []
      )
    else
      # Format suggestions as choices for the next turn
      choices_formatted = formatted_suggestions(response["suggestions"])

      # Create the new LifeEvent for the next year (with narrative = nil to avoid duplicates in feed)
      LifeEvent.create!(
        run: run,
        age: character.age,
        icon_type: "lightning",
        title: "Dialogue",
        narrative: nil,
        choices: choices_formatted
      )
    end

    character.save!
  end

  private

  def self.sanitize_stat(value)
    [[value.to_i, 100].min, 0].max
  end

  def self.sanitize_age_delta(value)
    return 1 if value.nil?

    value.to_i.clamp(0, 1)
  end

  def self.stat_delta(changes, key)
    changes[key].to_i
  end

  def self.formatted_suggestions(suggestions)
    Array(suggestions).first(3).filter_map.with_index do |suggestion, idx|
      text = suggestion.is_a?(Hash) ? suggestion["text"] : suggestion
      text = text.to_s.strip
      next if text.blank?

      { "id" => "suggest_#{idx}", "text" => text.first(80) }
    end
  end
end
