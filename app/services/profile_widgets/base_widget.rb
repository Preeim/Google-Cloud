# ==============================================================================
# Bánk's Repository - Moduláris Profil Widget Alaposztály (BaseWidget)
# ==============================================================================
# Tiszta absztrakciós interfész a profiloldali modul-panelek számára.
# Minden új modul vagy Rails Engine ezt az ősosztályt valósítja meg, vagy
# a ProfileWidgetRegistry-n keresztül konfigurálható.
# ==============================================================================

module ProfileWidgets
  class BaseWidget
    attr_reader :id, :title, :icon, :partial, :priority, :column_span

    def initialize(id:, title:, icon:, partial:, priority: 50, column_span: 1, owner_only: false)
      @id = id.to_sym
      @title = title
      @icon = icon
      @partial = partial
      @priority = priority
      @column_span = column_span
      @owner_only = owner_only
    end

    def owner_only?
      @owner_only
    end

    # Jogosultsági ellenőrzés:
    # - Ha owner_only: csak a profil tulajdonosának és adminnak jelenik meg.
    # - Ha publikus: bárki megtekintheti.
    def visible?(profile_user, viewer_user)
      if owner_only?
        return false unless viewer_user.present?
        return true if viewer_user.admin? || viewer_user.id == profile_user.id
        return false
      end
      true
    end

    # Előkészíti az adott widgethez szükséges adatokat a profil és a néző felhasználó alapján
    def load_data(profile_user, viewer_user)
      {}
    end
  end
end

