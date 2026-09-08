# frozen_string_literal: true

# ==============================================================================
# Bánk's Repository - User::Lockable Concern
# ==============================================================================
# Kezeli az ideiglenes fiókzárolást, a hibás és sikeres bejelentkezési
# kísérletek számlálását a brute-force támadások megelőzésére.
# ==============================================================================

module User::Lockable
  extend ActiveSupport::Concern

  # Ellenőrzi, hogy a fiók jelenleg ideiglenesen le van-e zárva
  def locked?
    locked_until.present? && locked_until > Time.current
  end

  # Fiók zárolása megadott időtartamra (alapértelmezetten 15 perc)
  def lock_access!(duration = 15.minutes)
    update_columns(locked_until: duration.from_now)
  end

  # Zárolás feloldása és hibás kísérlet számláló törlése
  def unlock_access!
    update_columns(failed_logins_count: 0, locked_until: nil)
  end

  # Sikeres bejelentkezés naplózása és számlálók alaphelyzetbe állítása
  def record_successful_login!
    update_columns(
      failed_logins_count: 0,
      locked_until: nil,
      last_login_at: Time.current
    )
  end

  # Hibás bejelentkezési kísérlet regisztrálása; 5 kísérlet után zárolás
  def record_failed_login!
    new_count = failed_logins_count + 1
    if new_count >= 5
      update_columns(failed_logins_count: new_count, locked_until: 15.minutes.from_now)
    else
      update_columns(failed_logins_count: new_count)
    end
  end
end
