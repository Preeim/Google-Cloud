# ==============================================================================
# Bánk's Repository - Regisztrációs Vezérlő (RegistrationsController)
# ==============================================================================
# Új felhasználók biztonságos létrehozása, szigorú paraméter-szűréssel
# (tömeges hozzárendelés elleni védelem), munkamenet-iniciálással és auditálással.
# ==============================================================================

class RegistrationsController < ApplicationController
  before_action :check_honeypot, only: [:create]
  before_action :set_no_cache_headers

  def new
    redirect_to root_path if logged_in?
    @user = User.new
  end

  def create
    redirect_to root_path if logged_in?

    u_params = user_params
    @user = User.new(u_params)

    # A regisztrált felhasználók kizárólag 'user' szerepkört kaphatnak
    @user.role = "user"
    @user.status = "active"

    if @user.save
      # Session Fixation elleni védelem
      reset_session

      # Munkamenet rögzítése
      raw_token, session_record = ActiveSession.create_from_request!(@user, request)
      session[:user_id] = @user.id
      session[:session_token] = raw_token

      # Regisztráció rögzítése a naplóban
      AuditLog.log!(
        action: "user_registered",
        actor: @user,
        target: @user,
        request: request,
        metadata: { username: @user.username, email: @user.email }
      )

      flash[:notice] = "Fiókod sikeresen létrejött! Üdvözlünk a Bánk's Repository platformon, #{@user.username}!"
      redirect_to root_path
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Honeypot mező ellenőrzése az automatizált regisztrációs botok kiszűrésére
  def check_honeypot
    if params[:hp_security_verification].present?
      AuditLog.log!(
        action: "bot_registration_blocked",
        actor: nil,
        target: nil,
        request: request,
        metadata: { ip: request.remote_ip, honeypot_value: params[:hp_security_verification] }
      )
      flash[:alert] = "Biztonsági ellenőrzés sikertelen. Kérjük töltsd ki újra az űrlapot."
      redirect_to register_path
    end
  end

  # Tömeges hozzárendelés (Mass Assignment) elleni védelem: csak a szükséges mezők, bemeneti adatok előtisztítása
  def user_params
    cleaned = params.require(:user).permit(:username, :email, :password, :password_confirmation)
    cleaned[:username] = cleaned[:username].to_s.strip if cleaned[:username].present?
    cleaned[:email] = cleaned[:email].to_s.strip.downcase if cleaned[:email].present?
    cleaned
  end

  def set_no_cache_headers
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0, private"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end
end

