require "test_helper"

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

  test "play_turn updates stats, stores reply, and keeps age when age_delta is zero" do
    response = {
      "reply" => "Vous trouvez un travail etudiant au cafe du coin.",
      "proposed_changes" => {
        "cash_delta" => 150,
        "health" => -5,
        "happiness" => 10
      },
      "age_delta" => 0,
      "suggestions" => ["Travailler dur", "Se reposer", "Demissionner"]
    }

    stub_gemini(response) do
      GameEngine.play_turn(@character, choice_id: "start")
    end

    @character.reload
    assert_equal 1150, @character.cash
    assert_equal 75, @character.health
    assert_equal 90, @character.happiness
    assert_equal 18, @character.age

    resolved_event = @run.life_events.order(id: :asc).first
    assert_equal "Avancer", resolved_event.player_custom_action
    assert_equal "Vous trouvez un travail etudiant au cafe du coin.", resolved_event.resolution_narrative
    assert_equal 150, resolved_event.applied_changes["cash_delta"]

    next_event = @run.life_events.order(id: :asc).last
    assert_nil next_event.narrative
    assert_equal 3, next_event.choices.size
    assert_equal "suggest_0", next_event.choices[0]["id"]
    assert_equal "Travailler dur", next_event.choices[0]["text"]
  end

  test "play_turn increments age when age_delta is one" do
    response = {
      "reply" => "Une annee s'ecoule paisiblement a la fac.",
      "proposed_changes" => {},
      "age_delta" => 1,
      "suggestions" => []
    }

    stub_gemini(response) do
      GameEngine.play_turn(@character, choice_id: "start")
    end

    assert_equal 19, @character.reload.age
  end

  test "play_turn handles missing keys gracefully" do
    stub_gemini({ "reply" => "Evenement etrange." }) do
      GameEngine.play_turn(@character, choice_id: "start")
    end

    @character.reload
    assert_equal 19, @character.age
    assert_equal 1000, @character.cash
  end

  test "play_turn clamps unsafe age_delta and coerces numeric stat strings" do
    response = {
      "reply" => "Vous tentez quelque chose de risque.",
      "proposed_changes" => {
        "cash_delta" => "75",
        "health" => "-20"
      },
      "age_delta" => 7,
      "suggestions" => [{ "text" => "Continuer" }, "", "  Observer  ", "Ignorer" ]
    }

    stub_gemini(response) do
      GameEngine.play_turn(@character, choice_id: "start")
    end

    @character.reload
    assert_equal 19, @character.age
    assert_equal 1075, @character.cash
    assert_equal 60, @character.health

    next_event = @run.life_events.order(id: :asc).last
    assert_equal ["Continuer", "Observer"], next_event.choices.map { |choice| choice["text"] }
  end

  test "play_turn retires when dynamic age reaches one hundred" do
    @character.update!(age: 99)
    @event.update!(age: 99)

    response = {
      "reply" => "Une derniere annee decisive passe.",
      "proposed_changes" => {},
      "age_delta" => 1,
      "suggestions" => ["Continuer"]
    }

    stub_gemini(response) do
      GameEngine.play_turn(@character, choice_id: "start")
    end

    assert_equal 100, @character.reload.age
    assert_equal "retired", @run.reload.status
    assert_match(/Retraite/, @run.life_events.order(id: :asc).last.title)
  end

  test "play_turn sends recent resolved history excluding the active placeholder" do
    6.times do |idx|
      LifeEvent.create!(
        run: @run,
        age: 18,
        title: "Tour #{idx}",
        player_custom_action: "Action #{idx}",
        resolution_narrative: "Resolution #{idx}"
      )
    end
    active_event = LifeEvent.create!(run: @run, age: 18, title: "Dialogue", choices: [])
    captured_history = nil
    response = { "reply" => "Suite.", "proposed_changes" => {}, "age_delta" => 0, "suggestions" => [] }

    stub_gemini(lambda { |_character, last_event, _action, history|
      assert_equal active_event, last_event
      captured_history = history
      response
    }) do
      GameEngine.play_turn(@character, custom_action: "Agir")
    end

    assert_equal 5, captured_history.size
    assert_equal ["Tour 1", "Tour 2", "Tour 3", "Tour 4", "Tour 5"], captured_history.map(&:title)
  end

  private

  def stub_gemini(response, &block)
    original = GeminiClient.method(:resolve_turn)
    GeminiClient.define_singleton_method(:resolve_turn) do |*args|
      response.respond_to?(:call) ? response.call(*args) : response
    end

    block.call
  ensure
    GeminiClient.define_singleton_method(:resolve_turn) do |*args|
      original.call(*args)
    end
  end
end
