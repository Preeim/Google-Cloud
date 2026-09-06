# ==============================================================================
# Bánk's Repository - Sakk Eredmények Profil Widget (ChessStatsWidget)
# ==============================================================================
# Publikus kártya: közvetlenül a Chess::Match adatbázis rekordokból számítja
# ki a játékos mérkőzésszámát, győzelmeit, vereségeit, döntetleneit és
# a legutóbbi partikat.
# ==============================================================================

module ProfileWidgets
  class ChessStatsWidget < BaseWidget
    def initialize
      super(
        id: :chess_stats,
        title: "Sakk Karrier & Statisztika",
        icon: "♟️",
        partial: "profiles/widgets/chess_stats",
        priority: 20,
        column_span: 1,
        owner_only: false
      )
    end

    def load_data(profile_user, viewer_user)
      matches = if defined?(Chess::Match)
                  Chess::Match.where("white_user_id = :uid OR black_user_id = :uid", uid: profile_user.id)
                else
                  []
                end

      total_games = matches.is_a?(Array) ? 0 : matches.count
      
      if total_games > 0
        wins = matches.where(
          "(white_user_id = :uid AND winner = 'white') OR (black_user_id = :uid AND winner = 'black')",
          uid: profile_user.id
        ).count

        draws = matches.where(winner: "draw").count
        completed_games = matches.where(status: "completed").count
        losses = [completed_games - (wins + draws), 0].max
        win_rate = completed_games > 0 ? ((wins.to_f / completed_games) * 100).round(1) : 0
        active_match = matches.where(status: ["pending", "active"]).order(created_at: :desc).first
        recent_matches = matches.order(created_at: :desc).limit(4)
      else
        wins = 0
        draws = 0
        losses = 0
        completed_games = 0
        win_rate = 0.0
        active_match = nil
        recent_matches = []
      end

      {
        total_games: total_games,
        wins: wins,
        draws: draws,
        losses: losses,
        completed_games: completed_games,
        win_rate: win_rate,
        active_match: active_match,
        recent_matches: recent_matches
      }
    end
  end
end

