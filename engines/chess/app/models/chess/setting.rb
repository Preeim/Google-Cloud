# ==============================================================================
# Bánk's Repository - Sakk Modul Beállítások Modell (Chess::Setting)
# ==============================================================================
# Kezeli a Sakk modul globális működési paramétereit (időkorlátok, vendégek,
# visszalépés engedélyezése, elévülési idők). Singleton jelleggel működik.
# ==============================================================================

module Chess
  class Setting < ApplicationRecord
    self.table_name = "chess_settings"

    validates :default_time_control, numericality: { greater_than_or_equal_to: 0 }
    validates :auto_abort_minutes, numericality: { greater_than_or_equal_to: 1 }

    def self.current
      first_or_create!(
        allow_guests: true,
        default_time_control: 600,
        available_time_controls: "0,180,300,600,900,1800",
        allow_takeback: true,
        allow_draw_offer: true,
        auto_abort_minutes: 30,
        single_challenge_limit: true
      )
    end

    # Visszaadja a választható időkorlátokat [[Label, Value], ...] formátumban
    def time_control_options
      available_time_controls.to_s.split(",").map(&:strip).map(&:to_i).uniq.sort.map do |secs|
        if secs <= 0
          ["Végtelen", ""]
        elsif secs < 60
          ["#{secs} másodperc (Bullet)", secs]
        elsif secs < 600
          ["#{secs / 60} perc (Blitz)", secs]
        else
          ["#{secs / 60} perc (Rapid)", secs]
        end
      end
    end
  end
end
