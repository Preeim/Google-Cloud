# frozen_string_literal: true

# ==============================================================================
# Bánk's Repository - Globális Chat Kontroller (ChatMessagesController)
# ==============================================================================
# REST fallback és előzmény-lekérdező végpont a Globális Chat számára.
# WebSocket kimaradás esetén is biztosítja az üzenetek elérését és küldését.
# ==============================================================================

class ChatMessagesController < ApplicationController
  before_action :authenticate_user!, only: [:create, :destroy]

  # GET /chat_messages
  def index
    messages = ChatMessage.recent(50).map { |m| m.to_chat_payload(current_user) }

    render json: {
      success: true,
      can_chat: logged_in? && current_user.active? && !current_user.locked?,
      is_moderator: moderator?,
      messages: messages
    }
  end

  # POST /chat_messages
  def create
    content = params[:content].to_s.strip

    if content.blank?
      render json: { success: false, error: "Az üzenet nem lehet üres." }, status: :unprocessable_entity
      return
    end

    if content.length > 1000
      render json: { success: false, error: "Az üzenet legfeljebb 1000 karakter hosszú lehet." }, status: :unprocessable_entity
      return
    end

    message = current_user.chat_messages.build(content: content)

    if message.save
      ActionCable.server.broadcast("global_chat", {
        action: "new_message",
        message: message.to_chat_payload(nil)
      })

      render json: {
        success: true,
        message: message.to_chat_payload(current_user)
      }, status: :created
    else
      render json: { success: false, error: message.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  # DELETE /chat_messages/:id
  def destroy
    message = ChatMessage.find_by(id: params[:id])

    unless message
      render json: { success: false, error: "Az üzenet nem található." }, status: :not_found
      return
    end

    can_delete = moderator? || message.user_id == current_user.id

    unless can_delete
      render json: { success: false, error: "Nincs jogosultságod az üzenet törléséhez." }, status: :forbidden
      return
    end

    message.soft_delete!

    ActionCable.server.broadcast("global_chat", {
      action: "message_deleted",
      message_id: message.id
    })

    render json: { success: true, message_id: message.id }
  end
end