# ==============================================================================
# Bánk's Repository - Rajzvászon Fő Vezérlő (Canvas::BoardsController)
# ==============================================================================

module Canvas
  class BoardsController < Canvas::ApplicationController
    before_action :set_board
    before_action :ensure_admin_access!, only: [:clear, :toggle_freeze]

    def show
      @strokes = @board.strokes.includes(:user).order(id: :asc).limit(300)
    end

    def clear
      @board.clear_canvas!

      # WebSocket értesítés küldése minden csatlakozott kliensnek
      Canvas::BoardChannel.broadcast_to(@board, {
        type: "board_cleared",
        by: current_user.username,
        cleared_at: Time.current.iso8601
      })

      respond_to do |format|
        format.html { redirect_to root_path, notice: "A rajzvászon sikeresen törölve lett!" }
        format.json { render json: { success: true, message: "A rajzvászon törölve." } }
      end
    end

    def toggle_freeze
      @board.toggle_freeze!

      state_text = @board.is_frozen? ? "zárolva" : "feloldva"

      # WebSocket értesítés küldése
      Canvas::BoardChannel.broadcast_to(@board, {
        type: "freeze_toggled",
        is_frozen: @board.is_frozen,
        by: current_user.username,
        message: "A rajzvászon #{state_text} lett."
      })

      respond_to do |format|
        format.html { redirect_to root_path, notice: "A rajzvászon állapota megváltozott: #{state_text}." }
        format.json { render json: { success: true, is_frozen: @board.is_frozen } }
      end
    end

    def save_snapshot
      return render json: { success: false, error: "Nincs jogosultságod pillanatfelvétel mentésére" }, status: :forbidden unless can_draw?(@board)

      snapshot = params[:snapshot]
      if snapshot.present? && snapshot.start_with?("data:image/")
        @board.save_snapshot!(snapshot)
        render json: { success: true }
      else
        render json: { success: false, error: "Érvénytelen képformátum" }, status: :unprocessable_entity
      end
    end

    private

    def set_board
      @board = Canvas::Board.default_board
    end

    def ensure_admin_access!
      unless current_user&.admin?
        respond_to do |format|
          format.html { redirect_to root_path, alert: "Ehhez a művelethez rendszergazdai jogosultság szükséges!" }
          format.json { render json: { success: false, error: "Csak adminisztrátorok számára engedélyezett!" }, status: :forbidden }
        end
      end
    end
  end
end
