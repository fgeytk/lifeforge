require "test_helper"

# Dynamic pure-Ruby stub for GeminiClient
class << GeminiClient
  attr_accessor :mocked_response

  alias_method :original_resolve_turn, :resolve_turn rescue nil

  def resolve_turn(character, last_event, action_taken, history = [])
    @mocked_response || { "reply" => "Stubbed response" }
  end
end

class GameEngineTest < ActiveSupport::TestCase
  setup do
    @run = Run.create!(status: "active")
    @character = Character.create!(
      run: @run,
      first_name: "Jean",
      last_name: "Dupont",
      age: 18,
      location: "Paris",
      occupation: "Sans emploi",
      cash: 1000,
      health: 80,
      happiness: 80,
      intelligence: 50,
      fitness: 50,
      looks: 50,
      charisma: 50
    )
    @event = LifeEvent.create!(
      run: @run,
      age: 18,
      title: "Le Commencement",
      narrative: "Votre aventure commence.",
      choices: [{ "id" => "start", "text" => "Avancer" }]
    )
  end

  teardown do
    GeminiClient.mocked_response = nil
  end

  test "play_turn updates character stats and dynamics of age progression based on Gemini reply" do
    GeminiClient.mocked_response = {
      "reply" => "Vous trouvez un travail étudiant au café du coin. Cela vous fatigue mais rapporte un peu d'argent.",
      "proposed_changes" => {
        "cash_delta" => 150,
        "health" => -5,
        "happiness" => 10
      },
      "age_delta" => 0,
      "suggestions" => ["Travailler dur", "Se reposer", "Démissionner"]
    }

    GameEngine.play_turn(@character, choice_id: "start")

    @character.reload
    assert_equal 1150, @character.cash
    assert_equal 75, @character.health
    assert_equal 90, @character.happiness
    assert_equal 18, @character.age # age_delta was 0

    last_event = @run.life_events.order(id: :asc).first
    assert_equal "Avancer", last_event.player_custom_action
    assert_equal "Vous trouvez un travail étudiant au café du coin. Cela vous fatigue mais rapporte un peu d'argent.", last_event.resolution_narrative
    assert_equal 150, last_event.applied_changes["cash_delta"]

    next_event = @run.life_events.order(id: :asc).last
    assert_nil next_event.narrative
    assert_equal 3, next_event.choices.size
    assert_equal "suggest_0", next_event.choices[0]["id"]
    assert_equal "Travailler dur", next_event.choices[0]["text"]
  end

  test "play_turn increments age when age_delta is 1" do
    GeminiClient.mocked_response = {
      "reply" => "Une année s'écoule paisiblement à la fac.",
      "proposed_changes" => {},
      "age_delta" => 1,
      "suggestions" => []
    }

    GameEngine.play_turn(@character, choice_id: "start")

    @character.reload
    assert_equal 19, @character.age # age_delta was 1
  end

  test "play_turn handles invalid or missing keys gracefully in response" do
    GeminiClient.mocked_response = {
      "reply" => "Événement étrange."
    }

    GameEngine.play_turn(@character, choice_id: "start")

    @character.reload
    assert_equal 19, @character.age # defaults to age_delta 1 if nil
    assert_equal 1000, @character.cash # unchanged
  end
end
