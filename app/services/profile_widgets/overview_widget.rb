# ==============================================================================
# Bánk's Repository - Áttekintés Profil Widget (OverviewWidget)
# ==============================================================================
# Publikus kártya: alapvető profiladatok, tagság dátuma, szerepkör,
# egyéni státusz és biográfia összefoglalója.
# ==============================================================================

module ProfileWidgets
  class OverviewWidget < BaseWidget
    def initialize
      super(
        id: :overview,
        title: "Profil Áttekintés",
        icon: "👤",
        partial: "profiles/widgets/overview",
        priority: 10,
        column_span: 1,
        owner_only: false
      )
    end

    def load_data(profile_user, viewer_user)
      {
        registered_at: profile_user.created_at,
        last_seen_at: profile_user.last_seen_at,
        online: profile_user.online?,
        role: profile_user.role,
        status: profile_user.status,
        custom_status: profile_user.custom_status,
        bio: profile_user.bio,
        display_name: profile_user.effective_name,
        avatar_color: profile_user.custom_avatar_color,
        is_owner: viewer_user.present? && (viewer_user.id == profile_user.id || viewer_user.admin?)
      }
    end
  end
end

