class TestChannel < ApplicationCable::Channel
  def subscribed
    stream_from "test_channel"
  end

  def unsubscribed
    # Cleanup when disconnected
  end

  # Live latency ping/pong
  def ping(data)
    transmit({ action: "pong", client_time: data["client_time"], server_time: (Time.now.to_f * 1000).round })
  end

  # Broadcast message to all open browser windows
  def speak(data)
    clean_message = ERB::Util.html_escape(data["message"].to_s.strip[0..500])
    raw_sender = current_user&.username || data["sender"].to_s.strip[0..50]
    clean_sender = ERB::Util.html_escape(raw_sender.presence || "Guest")

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

