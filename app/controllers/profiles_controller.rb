# ==============================================================================
# Bánk's Repository - Felhasználói Profil Vezérlő (ProfilesController)
# ==============================================================================
# Felelős a saját és nyilvános profiloldalak megjelenítéséért, a dinamikus
# moduláris widgetek összeállításáért, valamint a testreszabható profiladatok
# mentéséért.
# ==============================================================================

class ProfilesController < ApplicationController
  before_action :set_user, only: [:show]
  before_action :authenticate_user!, only: [:update]

  # GET /profile vagy GET /profile/:id vagy GET /users/:id
  def show
    unless @user
      flash[:alert] = "A keresett felhasználói profil nem található."
      redirect_to root_path and return
    end

    @is_own_profile = logged_in? && (current_user.id == @user.id)
    @can_edit = @is_own_profile || admin?

    # Dinamikus widgetek lekérése a regiszterből a néző jogosultsága alapján
    @widgets = ProfileWidgets::ProfileWidgetRegistry.widgets_for(@user, current_user)
  end

  # PATCH /profile vagy PATCH /profile/:id
  def update
    target_user = if admin? && params[:id].present?
                    User.find_by(id: params[:id]) || current_user
                  else
                    current_user
                  end

    if target_user.update(profile_params)
      # Ha a Presence csatornán is be van jelentkezve, szétküldjük a frissített állapotot
      begin
        ActionCable.server.broadcast("presence_channel", {
          action: "user_updated",
          user: {
            id: target_user.id,
            username: target_user.username,
            display_name: target_user.effective_name,
            avatar_color: target_user.custom_avatar_color,
            avatar_initials: target_user.avatar_initials,
            custom_status: target_user.custom_status.to_s,
            role: target_user.role,
            last_seen_at: (target_user.last_seen_at || Time.current).iso8601,
            profile_path: "/profile/#{target_user.id}"
          }
        })
      rescue StandardError => e
        Rails.logger.warn("PresenceChannel broadcast failed: #{e.message}")
      end

      flash[:notice] = "A profil adatai sikeresen frissültek!"
    else
      flash[:alert] = "Hiba a mentés során: #{target_user.errors.full_messages.join(', ')}"
    end

    redirect_to user_profile_path(target_user.id)
  end

  private

  def set_user
    if params[:id].present?
      @user = User.find_by(id: params[:id])
      @user ||= User.find_by("LOWER(username) = ?", params[:id].to_s.downcase)
    elsif logged_in?
      @user = current_user
    else
      flash[:alert] = "A saját profilod megtekintéséhez kérjük, jelentkezz be, vagy válassz ki egy felhasználót!"
      redirect_to login_path
    end
  end

  def profile_params
    params.require(:user).permit(:display_name, :bio, :custom_status, :avatar_color)
  end
end

