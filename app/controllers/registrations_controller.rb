# ==============================================================================
# Bánk's Repository - Regisztrációs Vezérlő (RegistrationsController)
# ==============================================================================
# Új felhasználók biztonságos létrehozása, szigorú paraméter-szűréssel
# (tömeges hozzárendelés elleni védelem), munkamenet-iniciálással és auditálással.
# ==============================================================================

class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if logged_in?
    @user = User.new
  end

  def create
    redirect_to root_path if logged_in?

    @user = User.new(user_params)
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

  # Tömeges hozzárendelés (Mass Assignment) elleni védelem: csak a szükséges mezők
  def user_params
    params.require(:user).permit(:username, :email, :password, :password_confirmation)
  end
end
