# ==============================================================================
# Bánk's Repository - WebSocket Kapcsolat Hitelesítő (ApplicationCable::Connection)
# ==============================================================================
# Az Action Cable WebSocket kézfogás (handshake) során ellenőrzi a kliens
# munkamenetét, azonosítja a felhasználót, és kizárja a zárolt/inaktív fiókokat.
# ==============================================================================

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      logger.add_tags "ActionCable", (current_user ? "User ##{current_user.id} (#{current_user.username})" : "Guest")
    end

    protected

    def find_verified_user
      session_key = Rails.application.config.session_options[:key]
      session_data = cookies.encrypted[session_key] rescue nil

      return nil unless session_data.is_a?(Hash)

      raw_token = session_data["session_token"]
      user_id   = session_data["user_id"]

      if raw_token.present?
        active_session = ActiveSession.find_by_raw_token(raw_token)
        if active_session && active_session.user_id == user_id
          user = active_session.user
          # Csak akkor engedélyezzük a kapcsolatot a fiókhoz, ha az aktív és nincs zárolva
          if user.active? && !user.locked?
            return user
          end
        end
      elsif user_id.present?
        # Visszafelé kompatibilis egyszerű azonosítás
        user = User.find_by(id: user_id)
        return user if user && user.active? && !user.locked?
      end

      # Vendég kapcsolatok engedélyezése publikus felületekhez (pl. ping/pong teszt)
      nil
    end
  end
end
