module Chess
  module Admin
    class SettingsController < BaseController
      before_action :set_settings

      def show
        render :edit
      end

      def edit
      end

      def update
        if @settings.update(settings_params)
          flash[:notice] = "A Sakk modul beállításai sikeresen mentve."
          redirect_to admin_settings_path
        else
          flash.now[:alert] = @settings.errors.full_messages.to_sentence
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_settings
        @settings = Chess::Setting.current
      end

      def settings_params
        params.require(:setting).permit(
          :allow_guests,
          :default_time_control,
          :available_time_controls,
          :allow_takeback,
          :allow_draw_offer,
          :auto_abort_minutes,
          :single_challenge_limit
        )
      end
    end
  end
end
