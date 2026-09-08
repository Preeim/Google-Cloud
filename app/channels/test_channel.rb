class TestChannel < ApplicationCable::Channel
  def subscribed
    unless current_user&.admin?
      reject
      return
    end

    stream_from "test_channel"
  end

  def unsubscribed
    stop_all_streams
  end

  # Live latency ping/pong
  def ping(data)
    return unless current_user&.admin?
    transmit({ action: "pong", client_time: data["client_time"], server_time: (Time.now.to_f * 1000).round })
  end

  # Broadcast message to all open browser windows (Admin-only diagnostic)
  def speak(data)
    return unless current_user&.admin?

    clean_message = ERB::Util.html_escape(data["message"].to_s.strip[0..500])
    raw_sender = current_user.username
    clean_sender = ERB::Util.html_escape(raw_sender)

    ActionCable.server.broadcast(
      "test_channel",
      {
        action: "new_message",
        message: clean_message,
        sender: clean_sender,
        time: Time.current.strftime("%H:%M:%S")
      }
    )
  end
end

