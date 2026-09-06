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
    ActionCable.server.broadcast(
      "test_channel",
      {
        action: "new_message",
        message: data["message"],
        sender: (current_user&.username || data["sender"] || "Guest"),
        time: Time.now.strftime("%H:%M:%S")
      }
    )
  end
end

