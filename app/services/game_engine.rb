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
    last_event = run.life_events.order(age: :asc).last
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

    # 3. Get history of recent events for LLM context
    history = run.life_events.order(age: :asc).limit(5).to_a

    # 4. Ask Gemini for resolution + next event
    response = GeminiClient.resolve_turn(character, last_event, action_text, history)

    # 5. Process resolution and update character stats
    resolution = response["resolution"]
    proposed = resolution["proposed_changes"] || {}

    # Update stats safely
    character.cash += (proposed["cash_delta"] || 0)
    character.health = sanitize_stat(character.health + (proposed["health"] || 0))
    character.happiness = sanitize_stat(character.happiness + (proposed["happiness"] || 0))
    character.intelligence = sanitize_stat(character.intelligence + (proposed["intelligence"] || 0))
    character.fitness = sanitize_stat(character.fitness + (proposed["fitness"] || 0))
    character.looks = sanitize_stat(character.looks + (proposed["looks"] || 0))
    character.charisma = sanitize_stat(character.charisma + (proposed["charisma"] || 0))

    # Update relationships
    if proposed["relationships"]
      proposed["relationships"].each do |name, val|
        current_val = character.relationships[name] || 50
        character.relationships[name] = sanitize_stat(current_val + val)
      end
    end

    # Add new relationships
    if resolution["new_relationships"]
      resolution["new_relationships"].each do |rel|
        name_key = "#{rel['name']} (#{rel['role']})"
        character.relationships[name_key] = sanitize_stat(rel["value"] || 50)
      end
    end

    # Remove relationships
    if resolution["removed_relationships"]
      resolution["removed_relationships"].each do |name|
        character.relationships.delete(name)
      end
    end

    # Manage assets
    if resolution["new_assets"]
      character.assets = (character.assets + resolution["new_assets"]).uniq
    end
    if resolution["removed_assets"]
      character.assets = character.assets - resolution["removed_assets"]
    end

    # Save resolution details to the event
    last_event.update!(
      selected_choice_id: choice_id,
      player_custom_action: custom_action,
      resolution_narrative: resolution["narrative"]
    )

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
      # Increment age and generate next event
      character.age += 1
      next_event = response["next_event"] || {}

      # Update occupation/location if changed in next_event or implied (optional simple logic)
      if next_event["narrative"] =~ /déménagez à ([^,.\n]+)/i
        character.location = $1.strip
      end

      # Create the new LifeEvent for the next year
      LifeEvent.create!(
        run: run,
        age: character.age,
        icon_type: next_event["icon_type"] || "lightning",
        title: next_event["title"] || "Une nouvelle année",
        narrative: next_event["narrative"] || "Les mois s'écoulent tranquillement.",
        choices: next_event["choices"] || [
          { "id" => "continue", "text" => "Continuer à vivre", "risk" => "none", "preview" => "Avancer" }
        ]
      )
    end

    character.save!
  end

  private

  def self.sanitize_stat(value)
    [[value.to_i, 100].min, 0].max
  end
end
