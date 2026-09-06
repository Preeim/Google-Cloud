# ==============================================================================
# Bánk's Repository - Kaszinó Profil Widget (CasinoStatsWidget)
# ==============================================================================
# Dinamikus modul kártya: a Casino::Profile és Casino::Transaction adatai.
# Jogosultsági finomhangolás: a publikus látogatók a zseton egyenleget és a
# győzelmi arányt látják, míg a részletes audit tranzakciók kizárólag a fiók
# tulajdonosának és az adminisztrátornak jelennek meg.
# ==============================================================================

module ProfileWidgets
  class CasinoStatsWidget < BaseWidget
    def initialize
      super(
        id: :casino_stats,
        title: "Kaszinó Klub & Egyenleg",
        icon: "🎰",
        partial: "profiles/widgets/casino_stats",
        priority: 30,
        column_span: 1,
        owner_only: false
      )
    end

    def load_data(profile_user, viewer_user)
      casino_profile = profile_user.casino_profile
      is_owner = viewer_user.present? && (viewer_user.id == profile_user.id || viewer_user.admin?)

      if casino_profile
        chips = casino_profile.chips
        total_rounds = casino_profile.total_rounds_played
        won_rounds = casino_profile.total_won_rounds
        win_rate = total_rounds > 0 ? ((won_rounds.to_f / total_rounds) * 100).round(1) : 0
        recent_transactions = is_owner ? casino_profile.transactions.order(created_at: :desc).limit(4) : []
      else
        chips = 0
        total_rounds = 0
        won_rounds = 0
        win_rate = 0.0
        recent_transactions = []
      end

      {
        has_profile: casino_profile.present?,
        chips: chips,
        total_rounds: total_rounds,
        won_rounds: won_rounds,
        win_rate: win_rate,
        is_owner: is_owner,
        recent_transactions: recent_transactions
      }
    end
  end
end

