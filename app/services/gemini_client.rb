require "net/http"
require "json"

class GeminiClient
  API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

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

    call_gemini(prompt, "gemini-3.5-flash") ||
      call_gemini(prompt, "gemini-3.1-flash-lite") ||
      mock_character(starting_prompt)
  end

  def self.resolve_turn(character, last_event, action_taken, history = [])
    # Build history context from past events
    history_context = history.map do |e|
      parts = []
      parts << "Age #{e.age}"
      parts << "AI Narrative: #{e.narrative}" if e.narrative.present?
      parts << "Player Action: #{e.player_custom_action || e.selected_choice_id}" if (e.player_custom_action || e.selected_choice_id).present?
      parts << "AI Resolution: #{e.resolution_narrative}" if e.resolution_narrative.present?
      parts.join(" | ")
    end.reject(&:blank?).join("\n")

    fallback_event = history.reverse.find { |e| e.resolution_narrative.present? || e.narrative.present? }
    last_situation =
      last_event.narrative.presence ||
      last_event.resolution_narrative.presence ||
      fallback_event&.resolution_narrative.presence ||
      fallback_event&.narrative.presence ||
      "Le joueur attend la prochaine situation."

    prompt = <<~PROMPT
      You are the Game Master of Lifeforge, a realistic life simulator.
      Resolve the character's turn based on their action and current state.
      The game is a continuous chat-based RPG dialogue. You are responding to the user's action and setting up the next situation.

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

      LAST SITUATION PRESENTED:
      "#{last_situation}"

      ACTION TAKEN BY PLAYER:
      "#{action_taken}"

      Return a JSON object matching this schema:
      {
        "reply": "string (the immediate consequence of the action taken and the description of the next situation/question for the player, 2-3 sentences)",
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
        "age_delta": integer (either 0 or 1. Use 0 for short-term/immediate actions, use 1 if the action takes time or if a year should pass),
        "suggestions": [
          "string (short quick-reply suggestion 1, max 45 chars)",
          "string (short quick-reply suggestion 2, max 45 chars)",
          "string (short quick-reply suggestion 3, max 45 chars)"
        ],
        "new_relationships": [
          { "name": "string", "role": "string", "value": integer }
        ],
        "removed_relationships": ["string"],
        "new_assets": ["string"],
        "removed_assets": ["string"]
      }

      Do NOT return any markdown wrapping (no ```json). Output raw JSON.
      Respond in French. Ensure the narration is engaging, modern and feels like a tabletop RPG master.
    PROMPT

    call_gemini(prompt, "gemini-3.5-flash") ||
      call_gemini(prompt, "gemini-3.1-flash-lite") ||
      mock_resolution(character, last_event, action_taken)
  end

  private

  def self.call_gemini(prompt, model)
    return nil if api_key.blank?

    uri = URI("#{API_BASE_URL}/#{model}:generateContent?key=#{api_key}")
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
      Rails.logger.error("Gemini API Error for #{model}: #{res.body}")
      nil
    end
  rescue => e
    Rails.logger.error("Gemini Client Error for #{model}: #{e.message}")
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
    scenarios = [
      {
        reply: "Votre action '#{action_taken}' a attiré l'attention d'un recruteur local. Il vous propose un entretien rapide.",
        cash_delta: 0, health: 0, happiness: 5, intelligence: 1, fitness: 0, looks: 0, charisma: 2,
        suggestions: ["Accepter l'entretien", "Refuser pour rester concentré", "Négocier les conditions d'abord"]
      },
      {
        reply: "Suite à votre initiative ('#{action_taken}'), vous passez une excellente soirée avec vos proches. Cela recharge vos batteries.",
        cash_delta: -50, health: 5, happiness: 15, intelligence: 0, fitness: 0, looks: 0, charisma: 1,
        suggestions: ["Proposer de recommencer le week-end", "Rentrer tôt pour vous reposer", "Leur raconter vos projets"]
      },
      {
        reply: "En tentant de faire cela ('#{action_taken}'), vous trébuchez et vous foulez légèrement la cheville. Rien de grave, mais c'est douloureux.",
        cash_delta: -20, health: -10, happiness: -5, intelligence: 0, fitness: -2, looks: 0, charisma: 0,
        suggestions: ["Aller à la pharmacie", "Ignorer la douleur et continuer", "Prendre un jour de repos"]
      },
      {
        reply: "Votre démarche ('#{action_taken}') s'avère particulièrement lucrative. Vous trouvez un moyen d'optimiser vos dépenses.",
        cash_delta: 250, health: 0, happiness: 10, intelligence: 2, fitness: 0, looks: 0, charisma: 0,
        suggestions: ["Placer cet argent de côté", "S'offrir un petit cadeau", "Investir dans du matériel"]
      }
    ]

    selected = scenarios.sample

    {
      "reply" => selected[:reply],
      "proposed_changes" => {
        "cash_delta" => selected[:cash_delta],
        "health" => selected[:health],
        "happiness" => selected[:happiness],
        "intelligence" => selected[:intelligence],
        "fitness" => selected[:fitness],
        "looks" => selected[:looks],
        "charisma" => selected[:charisma],
        "relationships" => {}
      },
      "age_delta" => [0, 1].sample,
      "suggestions" => selected[:suggestions],
      "new_relationships" => [],
      "removed_relationships" => [],
      "new_assets" => [],
      "removed_assets" => []
    }
  end
end
