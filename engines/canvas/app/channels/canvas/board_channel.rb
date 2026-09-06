# ==============================================================================
# Bánk's Repository - Rajzvászon WebSocket Csatorna (Canvas::BoardChannel)
# ==============================================================================
# Kezeli a valós idejű koordináta-közvetítést (15–30 ms streaming), a vonalak
# állapotmentését, a jelenléti listát és az adminisztrátori táblavezérlést.
# ==============================================================================

module Canvas
  class BoardChannel < ApplicationCable::Channel
    def subscribed
      @board = Canvas::Board.default_board
      stream_for @board

      # Felhasználó jelenlét regisztrálása
      register_presence

      # Kezdeti állapot azonnali átadása az új belépőnek
      recent_strokes = @board.strokes.order(id: :asc).limit(200).map(&:as_payload)

      transmit({
        type: "initial_state",
        board_id: @board.id,
        is_frozen: @board.is_frozen,
        snapshot: @board.snapshot_data,
        strokes: recent_strokes,
        can_draw: can_draw?(@board),
        active_users: current_active_users
      })

      # Mások értesítése az új résztvevőről
      broadcast_presence
    end

    def unsubscribed
      unregister_presence
      broadcast_presence if @board
    end

    # Élő vonal kezdése
    def start_stroke(data)
      return unless can_draw?(@board)

      Canvas::BoardChannel.broadcast_to(@board, {
        type: "stroke_start",
        temp_id: data["temp_id"],
        user_id: current_user&.id,
        username: current_user ? current_user.effective_name : "Vendég",
        tool: data["tool"] || "brush",
        color: data["color"] || "#38bdf8",
        width: data["width"] || 4,
        start_point: data["point"]
      })
    end

    # Élő koordináta-köteg közvetítése rajzolás közben (15-30ms batch)
    def stream_points(data)
      return unless can_draw?(@board)

      Canvas::BoardChannel.broadcast_to(@board, {
        type: "stroke_stream",
        temp_id: data["temp_id"],
        points: data["points"]
      })
    end

    # Vonal lezárása és véglegesítése adatbázisban
    def finish_stroke(data)
      return unless can_draw?(@board)

      points = data["points"]
      return if points.blank? || !points.is_a?(Array)

      stroke = @board.strokes.create(
        user: current_user,
        tool: data["tool"] || "brush",
        color: data["color"] || "#38bdf8",
        width: data["width"] || 4,
        points_data: points.to_json
      )

      if stroke.persisted?
        Canvas::BoardChannel.broadcast_to(@board, {
          type: "stroke_finished",
          temp_id: data["temp_id"],
          stroke: stroke.as_payload
        })
      end
    rescue => e
      Rails.logger.error "[CanvasChannel] Hiba a stroke mentésekor: #{e.message}"
    end

    # Adminisztrátori táblatörlés
    def clear_board(data)
      return unless current_user&.admin?

      @board.clear_canvas!

      Canvas::BoardChannel.broadcast_to(@board, {
        type: "board_cleared",
        by: current_user.effective_name,
        cleared_at: Time.current.iso8601
      })
    end

    # Adminisztrátori táblazárolás váltás
    def toggle_freeze(data)
      return unless current_user&.admin?

      @board.toggle_freeze!
      state_text = @board.is_frozen? ? "zárolva" : "feloldva"

      Canvas::BoardChannel.broadcast_to(@board, {
        type: "freeze_toggled",
        is_frozen: @board.is_frozen,
        by: current_user.effective_name,
        message: "A rajzvászon #{state_text} lett."
      })
    end

    private

    def can_draw?(board)
      return false unless current_user && current_user.active? && !current_user.locked?
      return true if current_user.admin?
      return false if board&.is_frozen?
      true
    end

    def presence_key
      "canvas_presence_board_#{@board.id}"
    end

    def current_user_identifier
      if current_user
        "user_#{current_user.id}"
      else
        "guest_#{guest_id}"
      end
    end

    def current_user_info
      {
        id: current_user_identifier,
        username: current_user ? current_user.effective_name : "Vendég",
        avatar_color: current_user&.custom_avatar_color || "#64748b",
        avatar_initials: current_user ? current_user.avatar_initials : "V",
        can_draw: can_draw?(@board),
        is_admin: current_user&.admin? || false
      }
    end

    def register_presence
      return unless @board
      list = Rails.cache.read(presence_key) || {}
      list[current_user_identifier] = current_user_info.merge(last_seen: Time.current.to_i)
      Rails.cache.write(presence_key, list, expires_in: 30.minutes)
    end

    def unregister_presence
      return unless @board
      list = Rails.cache.read(presence_key) || {}
      list.delete(current_user_identifier)
      Rails.cache.write(presence_key, list, expires_in: 30.minutes)
    end

    def current_active_users
      return [] unless @board
      list = Rails.cache.read(presence_key) || {}
      # Tisztítjuk az 5 percnél régebbi bejegyzéseket
      cutoff = 5.minutes.ago.to_i
      active = list.select { |_k, v| v[:last_seen] && v[:last_seen] > cutoff }.values
      active
    end

    def broadcast_presence
      return unless @board
      Canvas::BoardChannel.broadcast_to(@board, {
        type: "presence_update",
        active_users: current_active_users
      })
    end
  end
end
