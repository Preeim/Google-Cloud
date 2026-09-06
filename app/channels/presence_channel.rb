# ==============================================================================
# Bánk's Repository - Jelenlét és Aktivitás Csatorna (PresenceChannel)
# ==============================================================================
# Kezeli a valós idejű online jelenlétet WebSocketen keresztül.
# Értesíti a klienst az online felhasználókról, szétküldi az új belépéseket,
# kilépéseket és a kliensoldali szívverés (heartbeat) állapotot.
# ==============================================================================

class PresenceChannel < ApplicationCable::Channel
  CHANNEL_NAME = "presence_channel"

  def subscribed
    stream_from CHANNEL_NAME

    if current_user
      current_user.touch_last_seen!
      broadcast_user_status("user_online", current_user)
    end

    # Azonnali kezdeti állapot átadása az újonnan csatlakozó kliensnek
    transmit({
      action: "initial_state",
      online_users: fetch_online_users_payload,
      online_count: User.online.count,
      server_time: Time.current.iso8601
    })
  end

  def unsubscribed
    if current_user
      # Opcionálisan frissítjük az időbélyeget és tájékoztatjuk a jelenléti listát
      ActionCable.server.broadcast(CHANNEL_NAME, {
        action: "user_offline",
        user_id: current_user.id,
        online_count: [User.online.where.not(id: current_user.id).count, 0].max,
        server_time: Time.current.iso8601
      })
    end
  end

  # Kliensoldali időszakos szívverés (heartbeat), ami frissen tartja a last_seen_at mezőt
  def appear(data = {})
    return unless current_user

    current_user.touch_last_seen!
    
    # Ha a kliens új státuszüzenetet küldött
    if data["custom_status"].present? && data["custom_status"].is_a?(String)
      clean_status = data["custom_status"].strip[0..119]
      current_user.update_columns(custom_status: clean_status)
    end

    broadcast_user_status("user_updated", current_user)
  end

  private

  def broadcast_user_status(action, user)
    ActionCable.server.broadcast(CHANNEL_NAME, {
      action: action,
      user: serialize_user(user),
      online_count: User.online.count,
      server_time: Time.current.iso8601
    })
  end

  def fetch_online_users_payload
    User.online.order(last_seen_at: :desc).limit(30).map { |u| serialize_user(u) }
  end

  def serialize_user(user)
    {
      id: user.id,
      username: user.username,
      display_name: user.effective_name,
      avatar_color: user.custom_avatar_color,
      avatar_initials: user.avatar_initials,
      custom_status: user.custom_status.to_s,
      role: user.role,
      last_seen_at: (user.last_seen_at || Time.current).iso8601,
      profile_path: "/profile/#{user.id}"
    }
  end
end

