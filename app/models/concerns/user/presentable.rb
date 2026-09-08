# frozen_string_literal: true

# ==============================================================================
# Bánk's Repository - User::Presentable Concern
# ==============================================================================
# Kezeli a megjelenítendő neveket, avatar kezdőbetűket és színeket.
# ==============================================================================

module User::Presentable
  extend ActiveSupport::Concern

  # Megjelenítendő név: ha van beállítva display_name, azt adja vissza, egyébként a username-et
  def effective_name
    display_name.presence || username
  end

  # Kezdőbetűk az avatarhoz (pl. "Bánk" -> "BÁ", "John Doe" -> "JD")
  def avatar_initials
    parts = effective_name.strip.split(/\s+/)
    if parts.length >= 2
      (parts[0][0].to_s + parts[1][0].to_s).upcase
    else
      effective_name[0..1].to_s.upcase
    end
  end

  # Biztonságos hex avatar szín
  def custom_avatar_color
    avatar_color.presence || "#38bdf8"
  end

  # Igaz, ha az utolsó aktivitás 5 percen belül történt
  def online?
    last_seen_at.present? && last_seen_at >= 5.minutes.ago
  end

  # Frissíti az utolsó aktivitás időbélyegét
  def touch_last_seen!
    update_columns(last_seen_at: Time.current)
  end
end
