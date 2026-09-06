# ==============================================================================
# Bánk's Repository - Admin Felhasználókezelő Vezérlő (Admin::UsersController)
# ==============================================================================
# Lehetővé teszi a felhasználók listázását, keresését, szerepkörük módosítását,
# a zárolt fiókok feloldását, illetve felfüggesztését az adminisztrátor által.
# ==============================================================================

module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:edit, :update, :unlock, :destroy]

    def index
      @users = User.order(created_at: :desc)
      if params[:search].present?
        query = "%#{params[:search].to_s.strip.downcase}%"
        @users = @users.where("LOWER(username) LIKE ? OR LOWER(email) LIKE ?", query, query)
      end
    end

    def edit
    end

    def update
      old_role = @user.role
      old_status = @user.status

      if @user.update(user_params)
        AuditLog.log!(
          action: "user_updated_by_admin",
          actor: current_user,
          target: @user,
          resource: @user,
          request: request,
          metadata: {
            old_role: old_role, new_role: @user.role,
            old_status: old_status, new_status: @user.status
          }
        )
        flash[:notice] = "Felhasználó (#{@user.username}) sikeresen frissítve."
        redirect_to admin_users_path
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    # Fiók zárolásának manuális azonnali feloldása
    def unlock
      @user.unlock_access!
      AuditLog.log!(
        action: "user_unlocked_by_admin",
        actor: current_user,
        target: @user,
        resource: @user,
        request: request
      )
      flash[:notice] = "Felhasználó (#{@user.username}) zárolása sikeresen feloldva."
      redirect_to admin_users_path
    end

    def destroy
      if @user == current_user
        flash[:alert] = "Saját adminisztrátori fiókodat nem törölheted!"
        redirect_to admin_users_path and return
      end

      username = @user.username
      @user.destroy

      AuditLog.log!(
        action: "user_deleted_by_admin",
        actor: current_user,
        target: nil,
        resource: nil,
        request: request,
        metadata: { deleted_username: username }
      )

      flash[:notice] = "Felhasználó (#{username}) sikeresen törölve."
      redirect_to admin_users_path
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:role, :status)
    end
  end
end

