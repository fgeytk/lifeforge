class RunsController < ApplicationController
  before_action :set_run, only: [:play, :destroy]

  def index
    if session[:run_id].present?
      @run = Run.find_by(id: session[:run_id])
      if @run
        @character = @run.character
        @events = @run.life_events.order(id: :asc)
        @active_event = @events.last
      else
        session[:run_id] = nil
      end
    end
  end

  def create
    starting_prompt = params[:starting_prompt]
    if starting_prompt.blank?
      flash[:alert] = "Veuillez décrire qui vous voulez être."
      redirect_to root_path and return
    end

    begin
      @run = GameEngine.start_run(starting_prompt)
      session[:run_id] = @run.id
      redirect_to root_path
    rescue => e
      Rails.logger.error("Error starting run: #{e.message}\n#{e.backtrace.join("\n")}")
      flash[:alert] = "Une erreur est survenue lors de la génération du personnage : #{e.message}"
      redirect_to root_path
    end
  end

  def play
    choice_id = params[:choice_id]
    custom_action = params[:custom_action]

    begin
      # 1. Play the turn
      GameEngine.play_turn(@run.character, choice_id: choice_id, custom_action: custom_action)

      # 2. Reload data for rendering
      @character = @run.character.reload
      @events = @run.life_events.order(id: :asc)
      @active_event = @events.last
      @resolved_event = @events[-2] # The event that was just resolved

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path }
      end
    rescue => e
      Rails.logger.error("Error playing turn: #{e.message}\n#{e.backtrace.join("\n")}")
      flash[:alert] = "Erreur de jeu : #{e.message}"
      redirect_to root_path
    end
  end

  def destroy
    session[:run_id] = nil
    redirect_to root_path
  end

  private

  def set_run
    @run = Run.find(params[:id])
  end
end
