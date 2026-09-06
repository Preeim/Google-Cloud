module ApplicationHelper
  # Dinamikus oldal cím beállítása vagy lekérése
  def page_title(title = nil)
    if title.present?
      content_for(:title, title)
    elsif content_for?(:title)
      content_for(:title)
    else
      default_page_title
    end
  end

  # Automatikus visszalépési útvonal meghatározása
  def page_back_url(fallback = nil)
    if content_for?(:back_url)
      content_for(:back_url)
    elsif fallback.present?
      fallback
    else
      path = request.path
      if path.start_with?("/casino/")
        "/casino"
      elsif path.start_with?("/chess/")
        "/chess"
      elsif path.start_with?("/canvas/")
        "/canvas"
      elsif path.start_with?("/bank-admin/")
        "/bank-admin"
      elsif path != "/" && path != ""
        "/"
      else
        nil
      end
    end
  end

  # Modul jelvényének és ikonjának feloldása az aktuális útvonal alapján
  def current_module_info
    path = request.path
    if path.start_with?("/chess/admin")
      { name: "Sakk Admin", icon: "♟️", badge_class: "badge-admin", color: "var(--chess-gold, #fbbf24)" }
    elsif path.start_with?("/chess")
      { name: "Sakk Mester", icon: "♟️", badge_class: "badge-chess", color: "var(--accent, #38bdf8)" }
    elsif path.start_with?("/casino/admin")
      { name: "Kaszinó Admin", icon: "🎰", badge_class: "badge-admin", color: "var(--casino-gold, #fbbf24)" }
    elsif path.start_with?("/casino")
      { name: "Grand Casino", icon: "🎰", badge_class: "badge-casino", color: "var(--casino-gold, #fbbf24)" }
    elsif path.start_with?("/canvas")
      { name: "Közösségi Rajzvászon", icon: "🎨", badge_class: "badge-canvas", color: "var(--accent, #38bdf8)" }
    elsif path.start_with?("/bank-admin")
      { name: "Admin Központ", icon: "🛡️", badge_class: "badge-admin", color: "var(--admin-accent, #a855f7)" }
    elsif path.start_with?("/profile")
      { name: "Felhasználói Fiók", icon: "👤", badge_class: "badge-profile", color: "var(--accent, #38bdf8)" }
    elsif path.start_with?("/test")
      { name: "Teszt Konzol", icon: "🛠️", badge_class: "badge-test", color: "var(--accent, #38bdf8)" }
    else
      { name: "Platform", icon: "💎", badge_class: "badge-main", color: "var(--accent, #38bdf8)" }
    end
  end

  private

  def default_page_title
    path = request.path
    if path == "/"
      "Kezdőlap"
    elsif path.start_with?("/chess/admin")
      "Sakk Adminisztráció"
    elsif path.start_with?("/chess")
      "Sakk Aréna"
    elsif path.start_with?("/casino/admin")
      "Kaszinó Adminisztráció"
    elsif path.start_with?("/casino")
      "Kaszinó Lobbi"
    elsif path.start_with?("/canvas")
      "Közösségi Rajzvászon"
    elsif path.start_with?("/bank-admin")
      "Rendszer Adminisztráció"
    elsif path.start_with?("/profile")
      "Felhasználói Profil"
    elsif path.start_with?("/login")
      "Bejelentkezés"
    elsif path.start_with?("/register")
      "Regisztráció"
    elsif path.start_with?("/test")
      "Rendszer Diagnosztika"
    else
      "Bánk's Repository"
    end
  end
end

