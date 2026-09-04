# ==============================================================================
# Bánk's Repository - Admin Modulkezelő Vezérlő (Admin::AppsController)
# ==============================================================================
# A platformhoz kapcsolt beépülő modulok (pl. Sakk, és jövőbeli eszközök)
# állapotának (aktív, karbantartás, tiltva) és beállításainak kezelése.
# ==============================================================================

module Admin
  class AppsController < BaseController
    before_action :set_app, only: [:edit, :update, :toggle]

    def index
      @apps = AppDefinition.order(:name)
    end

    def edit
    end

    def toggle
      old_state = @app.state
      backup_filename = nil

      if @app.state_active?
        # Kikapcsolás: Automatikus mentés készítése
        backup_result = AppBackupService.export!(@app, actor: current_user)
        backup_filename = backup_result[:filename] if backup_result[:success]

        @app.update!(state: "disabled")
        notice_msg = "A(z) #{@app.name} modul sikeresen KIKAPCSOLVA."
        notice_msg += " Mentés a szerveren rögzítve: #{backup_filename}." if backup_filename
      else
        # Bekapcsolás
        @app.update!(state: "active")
        notice_msg = "A(z) #{@app.name} modul sikeresen BEKAPCSOLVA (aktív)."
      end

      AuditLog.log!(
        action: @app.state_active? ? "app_enabled" : "app_disabled_with_backup",
        actor: current_user,
        resource: @app,
        request: request,
        metadata: { old_state: old_state, new_state: @app.state, backup_file: backup_filename }
      )

      flash[:notice] = notice_msg
      redirect_to admin_apps_path
    end

    def update
      old_state = @app.state
      if @app.update(app_params)
        AuditLog.log!(
          action: "app_definition_updated",
          actor: current_user,
          resource: @app,
          request: request,
          metadata: { old_state: old_state, new_state: @app.state }
        )
        flash[:notice] = "A(z) #{@app.name} modul beállításai sikeresen frissültek."
        redirect_to admin_apps_path
      else
        flash.now[:alert] = @app.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_app
      @app = AppDefinition.find(params[:id])
    end

    def app_params
      params.require(:app_definition).permit(:name, :description, :state, :is_default_accessible, :requires_login)
    end
  end
end

