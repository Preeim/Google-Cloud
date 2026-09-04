# ==============================================================================
# Bánk's Repository - Admin Modulkezelő Vezérlő (Admin::AppsController)
# ==============================================================================
# A platformhoz kapcsolt beépülő modulok (pl. Sakk, és jövőbeli eszközök)
# állapotának (aktív, karbantartás, tiltva) és beállításainak kezelése.
# ==============================================================================

module Admin
  class AppsController < BaseController
    before_action :set_app, only: [:edit, :update]

    def index
      @apps = AppDefinition.order(:name)
    end

    def edit
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

