# frozen_string_literal: true

# ==============================================================================
# Bánk's Repository - Globális Chat Üzenet Modell (ChatMessage)
# ==============================================================================
# Felelős a globális chat üzenetek tárolásáért, validációjáért,
# szerializációjáért és a moderátori soft-delete mechanizmusért.
# ==============================================================================

class ChatMessage < ApplicationRecord
  belongs_to :user

  # Alapvető validációk
  validates :content, presence: true, length: { minimum: 1, maximum: 1000 }
  validate :user_must_be_active_and_unlocked, on: :create

  # Hatókörök (Scopes)
  scope :active, -> { where(deleted_at: nil) }
  scope :recent, ->(limit_count = 50) {
    active.includes(:user).order(created_at: :desc).limit(limit_count).to_a.reverse
  }

  # Soft delete moderációhoz
  def soft_delete!
    update_columns(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  # JSON / WebSocket szerializálás a kliens felé
  def to_chat_payload(current_viewer = nil)
    is_admin_or_mod = current_viewer.present? && (current_viewer.admin? || current_viewer.moderator?)
    can_delete = is_admin_or_mod || (current_viewer.present? && current_viewer.id == user_id)

    {
      id: id,
      content: ERB::Util.html_escape(content.to_s.strip),
      created_at: created_at.iso8601,
      formatted_time: format_timestamp,
      user: {
        id: user.id,
        username: ERB::Util.html_escape(user.username),
        display_name: ERB::Util.html_escape(user.effective_name),
        avatar_color: ERB::Util.html_escape(user.custom_avatar_color),
        avatar_initials: ERB::Util.html_escape(user.avatar_initials),
        role: user.role,
        profile_path: "/profile/#{user.id}"
      },
      can_delete: can_delete
    }
  end

  private

  def user_must_be_active_and_unlocked
    return unless user

    if !user.active?
      errors.add(:user, "fiókja nincs aktív állapotban")
    elsif user.locked?
      errors.add(:user, "fiókja jelenleg zárolva van")
    end
  end

  def format_timestamp
    t = created_at.in_time_zone("Budapest") rescue created_at
    if t.to_date == Date.current
      t.strftime("%H:%M")
    else
      t.strftime("%m.%d. %H:%M")
    end
  end
end