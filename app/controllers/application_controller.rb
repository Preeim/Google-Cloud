# ==============================================================================
# Bánk's Repository - Központi Alkalmazás Vezérlő (ApplicationController)
# ==============================================================================
# A platform összes vezérlőjének (és a beépülő Rails Engine-eknek) alaposztálya.
# Kezeli a munkamenet-érvényesítést, az RBAC jogosultsági ellenőrzéseket,
# a vendég / bejelentkezett app-hozzáférést és a hibamentes útvonal-átirányításokat.
# ==============================================================================

class ApplicationController < ActionController::Base
  # CSRF védelem bekapcsolása kivételkezeléssel
  protect_from_forgery with: :exception

  # Nézetekben és Engine sablonokban elérhető segédmetódusok
  helper ApplicationHelper rescue nil
  helper_method :current_user, :logged_in?, :admin?, :moderator?,
                :current_active_session, :app_login_path, :app_root_path,
                :app_logout_path, :app_register_path, :app_admin_root_path,
                :app_my_profile_path, :app_user_profile_path

  # Biztonságos útvonal-lekérők (Engine-ekből hívva is garantáltan működnek)
  def app_login_path
    if respond_to?(:main_app) && main_app.respond_to?(:login_path)
      main_app.login_path
    elsif respond_to?(:login_path)
      login_path
    else
      "/login"
    end
  end

  def app_logout_path
    if respond_to?(:main_app) && main_app.respond_to?(:logout_path)
      main_app.logout_path
    elsif respond_to?(:logout_path)
      logout_path
    else
      "/logout"
    end
  end

  def app_register_path
    if respond_to?(:main_app) && main_app.respond_to?(:register_path)
      main_app.register_path
    elsif respond_to?(:register_path)
      register_path
    else
      "/register"
    end
  end

  def app_admin_root_path
    if respond_to?(:main_app) && main_app.respond_to?(:admin_root_path)
      main_app.admin_root_path
    elsif respond_to?(:admin_root_path)
      admin_root_path
    else
      "/bank-admin"
    end
  end

  def app_root_path
    if respond_to?(:main_app) && main_app.respond_to?(:root_path)
      main_app.root_path
    elsif respond_to?(:root_path)
      root_path
    else
      "/"
    end
  end

  def app_my_profile_path
    if respond_to?(:main_app) && main_app.respond_to?(:my_profile_path)
      main_app.my_profile_path
    elsif respond_to?(:my_profile_path)
      my_profile_path
    else
      "/profile"
    end
  end

  def app_user_profile_path(user)
    user_id = user.is_a?(User) ? user.id : user
    if respond_to?(:main_app) && main_app.respond_to?(:user_profile_path)
      main_app.user_profile_path(user_id)
    elsif respond_to?(:user_profile_path)
      user_profile_path(user_id)
    else
      "/profile/#{user_id}"
    end
  end

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
        active_session = ActiveSession.find_by_raw_token(raw_token) rescue nil

        if active_session && active_session.user_id == user_id
          # Munkamenet frissítése (sliding expiration)
          active_session.touch_activity! rescue nil
          @current_active_session = active_session
          user = active_session.user
          if user && (user.last_seen_at.nil? || user.last_seen_at < 2.minutes.ago)
            user.touch_last_seen! rescue nil
          end
          user
        else
          # Ha a token érvénytelen vagy távolról törölték, töröljük a cookie-t
          reset_session
          nil
        end
      elsif user_id.present?
        user = User.find_by(id: user_id) rescue nil
        if user
          begin
            new_token, new_session = ActiveSession.create_from_request!(user, request)
            session[:session_token] = new_token
            @current_active_session = new_session
          rescue StandardError => e
            Rails.logger.warn("[ApplicationController] ActiveSession automatikus pótlása sikertelen: #{e.message}")
          end
          if user.last_seen_at.nil? || user.last_seen_at < 2.minutes.ago
            user.touch_last_seen! rescue nil
          end
        end
        user
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
      redirect_to app_login_path and return
    end

    # Fiók zárolásának vagy felfüggesztésének ellenőrzése
    if current_user.locked?
      reset_session
      flash[:alert] = "A fiókod ideiglenesen zárolva van gyanús tevékenység miatt. Kérjük, próbáld újra később!"
      redirect_to app_login_path and return
    elsif current_user.suspended?
      reset_session
      flash[:alert] = "A fiókodat az adminisztrátor felfüggesztette."
      redirect_to app_login_path and return
    end
  end

  # Kizárólag adminisztrátorok számára engedélyezett felületek védelme
  def require_admin!
    authenticate_user!
    return if performed?

    unless admin?
      flash[:alert] = "Hozzáférés megtagadva: Adminisztrátori jogosultság szükséges."
      redirect_to app_root_path and return
    end
  end

  # Beépülő modulok (pl. Sakk) rugalmas jogosultsági ellenőrzése
  # Szabályozza, hogy adott modulhoz kötelező-e a bejelentkezés, vagy vendégként is használható
  def check_app_access!(app_slug)
    app = AppDefinition.find_by(slug: app_slug)

    # 1. Ha az alkalmazás nem létezik az adatbázisban
    if app.nil?
      flash[:alert] = "A keresett modul nem létezik a platformon."
      redirect_to app_root_path and return
    end

    # 2. Ha az alkalmazás inaktív (kikapcsolt), karbantartás alatt van vagy csak adminoknak szól
    if app.state_disabled? || app.state_maintenance? || app.state_admin_only?
      if admin?
        # Rendszergazdáknak engedélyezzük a tesztelést és előnézetet
        flash.now[:alert] = "Figyelem: A(z) #{app.name} modul jelenleg #{app.state.upcase} állapotban van! (Csak adminisztrátori előnézet)"
      else
        @disabled_app = app
        render "shared/app_disabled", layout: "application", status: :service_unavailable and return
      end
    end

    # 3. Ha az alkalmazás NEM igényel bejelentkezést (requires_login: false), és nincs belépve:
    #    -> Nem dobjuk ki! Vendégként szabadon megnyithatja és használhatja!
    if !app.requires_login? && !logged_in?
      return true
    end

    # 4. Ha az alkalmazás bejelentkezést igényel, de nincs belépve:
    #    -> Kidobás helyett szép, barátságos értesítéssel átirányítjuk a bejelentkezéshez
    unless logged_in?
      flash[:alert] = "A(z) #{app.name} modul használatához kérjük, jelentkezz be a fiókodba, vagy hozz létre egy újat!"
      redirect_to app_login_path and return
    end

    # 5. Belépett felhasználó fiókállapotának ellenőrzése
    if current_user.locked?
      reset_session
      flash[:alert] = "A fiókod ideiglenesen zárolva van gyanús tevékenység miatt."
      redirect_to app_login_path and return
    elsif current_user.suspended?
      reset_session
      flash[:alert] = "A fiókodat az adminisztrátor felfüggesztette."
      redirect_to app_login_path and return
    end

    # 6. Granuláris felhasználói engedély vizsgálata
    unless current_user.can_access_app?(app_slug)
      flash[:alert] = "Ehhez a modulhoz (#{app.name}) egyéni engedély szükséges."
      redirect_to app_root_path and return
    end

    true
  end
end
