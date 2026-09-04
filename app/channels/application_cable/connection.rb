# ==============================================================================
# Bánk's Repository - WebSocket Kapcsolat Hitelesítő (ApplicationCable::Connection)
# ==============================================================================
# Az Action Cable WebSocket kézfogás (handshake) során ellenőrzi a kliens
# munkamenetét, azonosítja a felhasználót, és engedélyezi a kapcsolatot.
# ==============================================================================

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      if logger.respond_to?(:add_tags)
        tag = current_user ? "User ##{current_user.id} (#{current_user.username})" : "Guest"
        logger.add_tags("ActionCable", tag) rescue nil
      end
    end

    protected

    def find_verified_user
      session_key = Rails.application.config.session_options[:key]
      session_data = cookies.encrypted[session_key] rescue nil

      if session_data.is_a?(Hash)
        raw_token = session_data["session_token"]
        user_id   = session_data["user_id"]

        if raw_token.present?
          active_session = ActiveSession.find_by_raw_token(raw_token) rescue nil
          if active_session && active_session.user_id == user_id
            user = active_session.user
            return user if user&.active? && !user&.locked?
          end
        elsif user_id.present?
          user = User.find_by(id: user_id) rescue nil
          return user if user&.active? && !user&.locked?
        end
      end

      # Vendég (Guest) kapcsolatok engedélyezése a diagnosztikához és nyílt felületekhez
      nil
    rescue StandardError
      nil
    end
  end
end
