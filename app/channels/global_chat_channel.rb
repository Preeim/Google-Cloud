# frozen_string_literal: true

# ==============================================================================
# Bánk's Repository - Globális Chat Csatorna (GlobalChatChannel)
# ==============================================================================
# Kezeli a valós idejű globális csevegést WebSocketen keresztül.
# Támogatja az automatikus előzménybetöltést, üzenetszétküldést,
# moderátori üzenettörlést, valamint az XSS és flood védelmet.
# ==============================================================================

class GlobalChatChannel < ApplicationCable::Channel
  CHANNEL_STREAM = "global_chat"
  RATE_LIMIT_COUNT = 5
  RATE_LIMIT_PERIOD = 10.seconds
  MIN_INTERVAL = 0.5.seconds

  def subscribed
    stream_from CHANNEL_STREAM

    # Kezdeti előzmények és jogosultságok azonnali átadása a kliensnek
    is_mod = current_user.present? && (current_user.admin? || current_user.moderator?)
    can_chat = current_user.present? && current_user.active? && !current_user.locked?

    transmit({
      action: "initial_history",
      messages: ChatMessage.recent(50).map { |m| m.to_chat_payload(current_user) },
      can_chat: can_chat,
      is_moderator: is_mod,
      current_user: current_user ? {
        id: current_user.id,
        username: current_user.username,
        display_name: current_user.effective_name,
        role: current_user.role
      } : nil
    })
  end

  def unsubscribed
    # Szükség esetén tisztítás
  end

  # Új üzenet fogadása és szétküldése
  def speak(data)
    unless current_user && current_user.active? && !current_user.locked?
      transmit({ action: "error", message: "Csak bejelentkezett és aktív fiókkal lehet üzenetet küldeni." })
      return
    end

    # Flood védelem / Rate limit ellenőrzés
    if rate_limited?(current_user.id)
      transmit({ action: "error", message: "Túl gyors üzenetküldés (flood védelem). Kérjük várj néhány másodpercet!" })
      return
    end

    raw_content = data["content"].to_s.strip
    if raw_content.blank?
      transmit({ action: "error", message: "Az üzenet nem lehet üres." })
      return
    end

    if raw_content.length > 1000
      transmit({ action: "error", message: "Az üzenet legfeljebb 1000 karakter hosszú lehet." })
      return
    end

    chat_message = current_user.chat_messages.build(content: raw_content)

    if chat_message.save
      ActionCable.server.broadcast(CHANNEL_STREAM, {
        action: "new_message",
        message: chat_message.to_chat_payload(nil)
      })
    else
      transmit({ action: "error", message: chat_message.errors.full_messages.to_sentence })
    end
  end

  # Moderátori üzenettörlés valós időben
  def delete_message(data)
    message_id = data["message_id"].to_i
    msg = ChatMessage.find_by(id: message_id)

    unless msg
      transmit({ action: "error", message: "Az üzenet nem található." })
      return
    end

    can_delete = current_user.present? && (
      current_user.admin? ||
      current_user.moderator? ||
      current_user.id == msg.user_id
    )

    unless can_delete
      transmit({ action: "error", message: "Nincs jogosultságod az üzenet törléséhez." })
      return
    end

    msg.soft_delete!

    ActionCable.server.broadcast(CHANNEL_STREAM, {
      action: "message_deleted",
      message_id: msg.id
    })
  end

  private

  # Egyszerű, megbízható csúszóablakos kérésszám-korlátozó felhasználónként
  def rate_limited?(user_id)
    cache_key = "global_chat_rate:#{user_id}"
    now = Time.current.to_f
    timestamps = Rails.cache.read(cache_key) || []

    # Csak az elmúlt RATE_LIMIT_PERIOD másodpercben történt eseményeket tartjuk meg
    timestamps = timestamps.select { |t| (now - t) < RATE_LIMIT_PERIOD.to_i }

    # Túl gyakori egymás utáni üzenetküldés kivédése (< 0.5s)
    if timestamps.last && (now - timestamps.last) < MIN_INTERVAL.to_f
      return true
    end

    if timestamps.size >= RATE_LIMIT_COUNT
      return true
    end

    timestamps << now
    Rails.cache.write(cache_key, timestamps, expires_in: RATE_LIMIT_PERIOD)
    false
  rescue StandardError
    false
  end
end