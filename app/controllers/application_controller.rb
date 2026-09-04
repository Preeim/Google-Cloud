# ==============================================================================
# Bánk's Repository - Központi Alkalmazás Vezérlő (ApplicationController)
# ==============================================================================
# A platform összes vezérlőjének (és a beépülő Rails Engine-eknek) alaposztálya.
# Kezeli a munkamenet-érvényesítést, az RBAC jogosultsági ellenőrzéseket,
# a fiók-zárolás vizsgálatát és az App-hozzáférési szűrőket.
# ==============================================================================

class ApplicationController < ActionController::Base
  # CSRF védelem bekapcsolása kivételkezeléssel
  protect_from_forgery with: :exception

  # Nézetekben közvetlenül elérhető segédmetódusok
  helper_method :current_user, :logged_in?, :admin?, :moderator?, :current_active_session

  private

  # ============================================================================
  # Munkamenet és Felhasználói Kontextus
  # ============================================================================

  # Lekéri a jelenlegi bejelentkezett felhasználót az aktív munkamenet alapján
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = begin
      raw_token = session[:session_token]
      user_id   = session[:user_id]

      if raw_token.present? && user_id.present?
        # 1. Megkeressük az aktív munkamenet rekordot a token alapján
        active_session = ActiveSession.find_by_raw_token(raw_token)

        if active_session && active_session.user_id == user_id
          # Munkamenet frissítése (sliding expiration)
          active_session.touch_activity!
          @current_active_session = active_session
          active_session.user
        else
          # Ha a token érvénytelen vagy távolról törölték, töröljük a cookie-t
          reset_session
          nil
        end
      elsif user_id.present?
        # Visszafelé kompatibilitás fejlesztői módban
        User.find_by(id: user_id)
      end
    end
  end

  def current_active_session
    @current_active_session
  end

  # Igaz, ha van érvényesen bejelentkezett felhasználó
  def logged_in?
    current_user.present?
  end

  # Igaz, ha a bejelentkezett felhasználó rendszergazda (admin)
  def admin?
    logged_in? && current_user.admin?
  end

  # Igaz, ha a bejelentkezett felhasználó moderátor vagy admin
  def moderator?
    logged_in? && (current_user.moderator? || current_user.admin?)
  end

  # ============================================================================
  # Hozzáférés-védelmi Szűrők (Before Actions)
  # ============================================================================

  # Kötelező bejelentkezést előíró szűrő
  def authenticate_user!
    unless logged_in?
      flash[:alert] = "A kért oldal eléréséhez kérjük, jelentkezz be!"
      redirect_to login_path and return
    end

    # Fiók zárolásának vagy felfüggesztésének ellenőrzése
    if current_user.locked?
      reset_session
      flash[:alert] = "A fiókod ideiglenesen zárolva van gyanús tevékenység miatt. Kérjük, próbáld újra később!"
      redirect_to login_path and return
    elsif current_user.suspended?
      reset_session
      flash[:alert] = "A fiókodat az adminisztrátor felfüggesztette."
      redirect_to login_path and return
    end
  end

  # Kizárólag adminisztrátorok számára engedélyezett felületek védelme
  def require_admin!
    authenticate_user!
    return if performed?

    unless admin?
      flash[:alert] = "Hozzáférés megtagadva: Adminisztrátori jogosultság szükséges."
      redirect_to root_path and return
    end
  end

  # Beépülő modulok (pl. Sakk) jogosultsági ellenőrzése
  def check_app_access!(app_slug)
    authenticate_user!
    return if performed?

    unless current_user.can_access_app?(app_slug)
      flash[:alert] = "Nincs jogosultságod a(z) #{app_slug} modul eléréséhez, vagy az alkalmazás karbantartás alatt áll."
      redirect_to root_path and return
    end
  end
end
