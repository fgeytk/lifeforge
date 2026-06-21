require "net/http"
require "json"

class GeminiClient
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

  def self.api_key
    ENV["GEMINI_API_KEY"]
  end

  def self.generate_character(starting_prompt)
    prompt = <<~PROMPT
      You are the engine of Lifeforge, a realistic life simulator.
      Based on the following user start request, create a character.
      Start Request: "#{starting_prompt}"

      Return a JSON object matching this schema:
      {
        "first_name": "string",
        "last_name": "string",
        "age": integer (normally 18-22 unless starting prompt implies older/younger),
        "location": "string (City, Country)",
        "occupation": "string",
        "cash": integer (starting cash, realistic e.g. 500 to 5000 based on starting prompt),
        "health": integer (0 to 100, default 80-100),
        "happiness": integer (0 to 100, default 50-80),
        "intelligence": integer (0 to 100, default 40-90),
        "fitness": integer (0 to 100, default 40-90),
        "looks": integer (0 to 100, default 40-90),
        "charisma": integer (0 to 100, default 40-90),
        "starting_story": "string (2-3 sentences introducing the character's current situation)",
        "relationships": {
          "Name (Role)": integer (initial rating 50-90, e.g. "Sarah Cross (Mother)": 80)
        }
      }

      Do NOT return any markdown wrapping (no ```json). Output raw JSON.
      Respond in French for names, locations, occupations, stories, and relationships if the starting prompt is in French.
    PROMPT

    call_gemini(prompt) || mock_character(starting_prompt)
  end

  def self.resolve_turn(character, last_event, action_taken, history = [])
    history_context = history.map { |e| "Age #{e.age}: #{e.narrative} -> Selected Choice: #{e.selected_choice_id || e.player_custom_action}" }.join("\n")

    prompt = <<~PROMPT
      You are the engine of Lifeforge, a realistic life simulator.
      Resolve the character's turn based on their action and current state.

      CHARACTER STATE:
      - Name: #{character.full_name}
      - Age: #{character.age}
      - Location: #{character.location}
      - Occupation: #{character.occupation}
      - Cash: $#{character.cash}
      - Health: #{character.health}, Happiness: #{character.happiness}, Intelligence: #{character.intelligence}, Fitness: #{character.fitness}, Looks: #{character.looks}, Charisma: #{character.charisma}
      - Relationships: #{character.relationships.to_json}
      - Assets: #{character.assets.to_json}

      HISTORY OF RECENT EVENTS:
      #{history_context}

      LAST EVENT PRESENTED:
      "#{last_event.narrative}"

      ACTION TAKEN BY PLAYER:
      "#{action_taken}"

      Return a JSON object matching this schema:
      {
        "resolution": {
          "narrative": "string (the immediate consequence of the action taken, 2-3 sentences)",
          "proposed_changes": {
            "cash_delta": integer,
            "health": integer (change between -50 and +30),
            "happiness": integer (change between -50 and +30),
            "intelligence": integer (change between -10 and +10),
            "fitness": integer (change between -10 and +10),
            "looks": integer (change between -10 and +10),
            "charisma": integer (change between -10 and +10),
            "relationships": {
              "Relationship Name (Role)": integer (change, e.g. -15 or +10)
            }
          },
          "new_relationships": [
            { "name": "string", "role": "string", "value": integer }
          ],
          "removed_relationships": ["string"],
          "new_assets": ["string"],
          "removed_assets": ["string"]
        },
        "next_event": {
          "title": "string",
          "narrative": "string (the scenario that happens 1 year later at age #{character.age + 1}. Should feel like a natural consequence or random life event)",
          "icon_type": "string (lightning, heart, sparkles, briefcase, skull, info)",
          "choices": [
            { "id": "string", "text": "string (the button option)", "risk": "string (none, low, medium, high)", "preview": "string" }
          ]
        }
      }

      Do NOT return any markdown wrapping (no ```json). Output raw JSON.
      Respond in French. Ensure the narrative is engaging and realistic for our modern world.
    PROMPT

    call_gemini(prompt) || mock_resolution(character, last_event, action_taken)
  end

  private

  def self.call_gemini(prompt)
    return nil if api_key.blank?

    uri = URI("#{API_URL}?key=#{api_key}")
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    req.body = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: "application/json"
      }
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    if res.is_a?(Net::HTTPSuccess)
      json = JSON.parse(res.body)
      text = json.dig("candidates", 0, "content", "parts", 0, "text")
      JSON.parse(text)
    else
      Rails.logger.error("Gemini API Error: #{res.body}")
      nil
    end
  rescue => e
    Rails.logger.error("Gemini Client Error: #{e.message}")
    nil
  end

  def self.mock_character(starting_prompt)
    {
      "first_name" => "Alex",
      "last_name" => "Martin",
      "age" => 18,
      "location" => "Paris, France",
      "occupation" => "Étudiant",
      "cash" => 1000,
      "health" => 90,
      "happiness" => 75,
      "intelligence" => 80,
      "fitness" => 60,
      "looks" => 70,
      "charisma" => 65,
      "starting_story" => "Vous commencez votre aventure à Paris suite à votre demande : '#{starting_prompt}'. Votre avenir reste à écrire.",
      "relationships" => {
        "Marie Martin (Mère)" => 85,
        "Pierre Martin (Père)" => 70
      }
    }
  end

  def self.mock_resolution(character, last_event, action_taken)
    {
      "resolution" => {
        "narrative" => "Vous avez choisi : '#{action_taken}'. Les choses se déroulent de manière inattendue, mais vous parvenez à vous adapter.",
        "proposed_changes" => {
          "cash_delta" => 200,
          "health" => 5,
          "happiness" => 10,
          "intelligence" => 2,
          "fitness" => -1,
          "looks" => 0,
          "charisma" => 1,
          "relationships" => {
            "Marie Martin (Mère)" => 5
          }
        },
        "new_relationships" => [],
        "removed_relationships" => [],
        "new_assets" => [],
        "removed_assets" => []
      },
      "next_event" => {
        "title" => "Une nouvelle opportunité",
        "narrative" => "Un an s'est écoulé. À l'âge de #{character.age + 1} ans, vous faites face à un nouveau choix décisif pour votre avenir.",
        "icon_type" => "lightning",
        "choices" => [
          { "id" => "explore", "text" => "Explorer cette opportunité activement", "risk" => "medium", "preview" => "Risqué mais rentable." },
          { "id" => "ignore", "text" => "Passer votre chemin pour l'instant", "risk" => "none", "preview" => "Choix de la sécurité." }
        ]
      }
    }
  end
end
