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

      # Explicit join requested via params[:join]
      if @match.pending? && (params[:join] == "true" || params[:join] == "1")
        join_pending_match!
      end

      # Automatically evaluate timeout on match view
      if @match.active?
        @match.check_timeout!
      end
    end

    def join
      @match = Match.find_by!(uuid: params[:id])
      if @match.pending?
        join_pending_match!
      end
      redirect_to match_path(@match.uuid)
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

    private

    def join_pending_match!
      @match.with_lock do
        return unless @match.pending?

        is_creator = if @match.white_user_id.present? && current_user.present? && @match.white_user_id == current_user.id
                       true
                     elsif @match.black_user_id.present? && current_user.present? && @match.black_user_id == current_user.id
                       true
                     elsif @match.white_guest_id.present? && session[:guest_id].present? && @match.white_guest_id.to_s == session[:guest_id].to_s
                       true
                     elsif @match.black_guest_id.present? && session[:guest_id].present? && @match.black_guest_id.to_s == session[:guest_id].to_s
                       true
                     else
                       false
                     end

        return if is_creator

        white_open = @match.white_user_id.nil? && @match.white_guest_id.nil?
        black_open = @match.black_user_id.nil? && @match.black_guest_id.nil?

        if white_open
          if current_user.present?
            @match.update!(white_user_id: current_user.id, status: "active", last_move_at: Time.current)
          elsif session[:guest_id].present?
            @match.update!(white_guest_id: session[:guest_id], status: "active", last_move_at: Time.current)
          end
          Chess::MatchChannel.broadcast_to(@match, { action: "match_started" })
        elsif black_open
          if current_user.present?
            @match.update!(black_user_id: current_user.id, status: "active", last_move_at: Time.current)
          elsif session[:guest_id].present?
            @match.update!(black_guest_id: session[:guest_id], status: "active", last_move_at: Time.current)
          end
          Chess::MatchChannel.broadcast_to(@match, { action: "match_started" })
        end
      end
    end
  end
end

