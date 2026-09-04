module Chess
  class MatchesController < ApplicationController
    before_action :load_settings

    def index
      @pending_matches = Match.where(status: "pending").order(created_at: :desc)
      @user_matches = Match.where(
        "white_user_id = :uid OR black_user_id = :uid OR white_guest_id = :gid OR black_guest_id = :gid",
        uid: current_user&.id, gid: session[:guest_id]
      ).order(created_at: :desc).limit(10)
      @my_open_match = Match.open_match_for(current_user, session[:guest_id])
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
      # 1. Vendégjáték engedélyezésének ellenőrzése
      if !logged_in? && !@settings.allow_guests?
        flash[:alert] = "A Sakk modulban a vendégjáték jelenleg tiltva van a beállítások alapján. Kérjük, jelentkezz be!"
        redirect_to app_login_path and return
      end

      # 2. Egyidejű nyitott kihívás korlát ellenőrzése
      if @settings.single_challenge_limit?
        existing = Match.open_match_for(current_user, session[:guest_id])
        if existing
          flash[:alert] = "Már van egy nyitott vagy folyamatban lévő kihívásod! Fejezd be vagy vond vissza, mielőtt újat indítanál."
          redirect_to match_path(existing.uuid) and return
        end
      end

      # 3. Új meccs létrehozása
      match = Match.new

      if params[:time_control].present? && params[:time_control].to_i > 0
        match.time_control = params[:time_control].to_i
        match.white_time_left = match.time_control * 1000
        match.black_time_left = match.time_control * 1000
      end

      # Oldal kiosztása
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

    def cancel
      @match = Match.find_by!(uuid: params[:id])

      unless @match.creator?(current_user, session[:guest_id]) || admin?
        flash[:alert] = "Nincs jogosultságod visszavonni ezt a kihívást!"
        redirect_to match_path(@match.uuid) and return
      end

      if @match.pending?
        # Értesítjük a szobában esetlegesen tartózkodókat
        Chess::MatchChannel.broadcast_to(@match, { action: "challenge_cancelled" })
        @match.destroy
        flash[:notice] = "A sakk kihívást sikeresen visszavontad."
      else
        flash[:alert] = "A játszma már aktív vagy befejeződött, így nem vonható vissza."
      end

      redirect_to matches_path
    end

    def destroy
      cancel
    end

    private

    def load_settings
      @settings = Setting.current
    end

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

