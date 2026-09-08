# ==============================================================================
# Bánk's Repository - Bejelentkezési Vezérlő (SessionsController)
# ==============================================================================
# Felelős a felhasználói hitelesítésért, a brute-force elleni védelemért,
# a munkamenet-rögzítésért (ActiveSession) és a biztonságos kijelentkeztetésért.
# ==============================================================================

class SessionsController < ApplicationController
  before_action :set_no_cache_headers

  DUMMY_DIGEST = "$2a$12$e8Y5t11.zEekZ7j674vMoeT7ZkK.v52y/w4w0eM15V61f5kF.m/2m"

  def new
    redirect_to root_path if logged_in?
  end

  def create
    raw_login = params[:login].to_s.strip
    raw_password = params[:password].to_s

    login_input = raw_login.downcase
    user = User.find_by("LOWER(username) = ? OR LOWER(email) = ?", login_input, login_input)


    # 1. Fiók zárolásának ellenőrzése
    if user&.locked?
      minutes_left = ((user.locked_until - Time.current) / 60).ceil
      flash.now[:alert] = "A fiókod ideiglenesen zárolva van #{minutes_left} percig a túl sok hibás kísérlet miatt."
      render :new, status: :locked and return
    end

    # 2. Felfüggesztett fiók vizsgálata
    if user&.suspended?
      flash.now[:alert] = "Ez a fiók fel van függesztve. Kérjük, lépj kapcsolatba a rendszergazdával!"
      render :new, status: :forbidden and return
    end

    # 3. Hitelesítés bcrypt jelszó alapján (időzítés-alapú user enumeráció elleni dummy ellenőrzéssel)
    authenticated = if user
      user.authenticate(raw_password)
    else
      BCrypt::Password.new(DUMMY_DIGEST) == raw_password
      false
    end

    if authenticated
      # Sikeres bejelentkezés naplózása és számlálók törlése
      user.record_successful_login!

      # Session Fixation elleni védelem: korábbi session törlése és új ID generálása
      reset_session

      # Aktív munkamenet rekord rögzítése és titkosított cookie mentése
      raw_token, session_record = ActiveSession.create_from_request!(user, request)
      session[:user_id] = user.id
      session[:session_token] = raw_token

      # Admin belépés rögzítése az audit naplóban
      if user.admin?
        AuditLog.log!(
          action: "admin_login",
          actor: user,
          resource: user,
          request: request,
          metadata: { user_agent: request.user_agent }
        )
      end

      flash[:notice] = "Sikeres bejelentkezés! Üdvözlünk, #{user.username}!"
      redirect_to root_path
    else
      # Hibás belépés kezelése és számláló növelése
      if user
        user.record_failed_login!
        if user.locked?
          AuditLog.log!(
            action: "user_auto_locked",
            target: user,
            request: request,
            metadata: { reason: "5 consecutive failed password attempts" }
          )
          flash.now[:alert] = "Túl sok hibás próbálkozás! A fiókodat 15 percre lezártuk a biztonságod érdekében."
          render :new, status: :locked and return
        end
      end

      flash.now[:alert] = "Érvénytelen bejelentkezési adatok! Ellenőrizd a felhasználónevet/e-mail címet és a jelszót."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # Aktív munkamenet adatbázis rekordjának törlése
    if session[:session_token].present?
      active_session = ActiveSession.find_by_raw_token(session[:session_token])
      active_session&.destroy
    end

    # Session cookie teljes törlése
    reset_session
    flash[:notice] = "Sikeresen kijelentkeztél."
    redirect_to root_path
  end

  private

  def set_no_cache_headers
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0, private"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end
end
