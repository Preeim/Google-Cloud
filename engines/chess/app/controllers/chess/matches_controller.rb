module Chess
  class MatchesController < ApplicationController
    def index
      @pending_matches = Match.where(status: "pending").order(created_at: :desc)
      @user_matches = Match.where(
        "white_user_id = :uid OR black_user_id = :uid OR white_guest_id = :gid OR black_guest_id = :gid",
        uid: current_user&.id, gid: session[:guest_id]
      ).order(created_at: :desc).limit(10)
    end

    def show
      @match = Match.find_by!(uuid: params[:id])
      
      # Auto-join if pending and not the creator
      if @match.pending?
        is_creator = if current_user
                       @match.white_user_id == current_user.id || @match.black_user_id == current_user.id
                     else
                       @match.white_guest_id == session[:guest_id] || @match.black_guest_id == session[:guest_id]
                     end

        unless is_creator
          white_open = @match.white_user_id.nil? && @match.white_guest_id.nil?
          black_open = @match.black_user_id.nil? && @match.black_guest_id.nil?

          if white_open
            if current_user
              @match.update!(white_user_id: current_user.id, status: "active")
            else
              @match.update!(white_guest_id: session[:guest_id], status: "active")
            end
          elsif black_open
            if current_user
              @match.update!(black_user_id: current_user.id, status: "active")
            else
              @match.update!(black_guest_id: session[:guest_id], status: "active")
            end
          end
        end
      end
    end

    def create
      # Create a new match room
      match = Match.new
      
      if params[:time_control].present?
        match.time_control = params[:time_control].to_i
        match.white_time_left = match.time_control * 1000
        match.black_time_left = match.time_control * 1000
      end

      # Assign creator to a side
      side = %w[white black].sample
      side = params[:side] if %w[white black].include?(params[:side])

      if logged_in?
        match.send("#{side}_user_id=", current_user.id)
      else
        match.send("#{side}_guest_id=", session[:guest_id])
      end

      match.save!

      redirect_to match_path(match.uuid)
    end
  end
end
