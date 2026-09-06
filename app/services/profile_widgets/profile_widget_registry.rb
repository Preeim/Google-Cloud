# ==============================================================================
# Bánk's Repository - Profil Widget Nyilvántartó (ProfileWidgetRegistry)
# ==============================================================================
# Központi regiszter a profiloldali modulok kezelésére.
# Bármelyik meglévő vagy jövőbeli modul / Rails Engine egyszerűen felcsatolható:
#
#   ProfileWidgets::ProfileWidgetRegistry.register(MyCustomWidget.new)
#
# A profiloldal ebből a listából szűri le és jeleníti meg a dinamikus widgeteket.
# ==============================================================================

module ProfileWidgets
  class ProfileWidgetRegistry
    @widgets = []
    @defaults_registered = false

    class << self
      def register(widget)
        @widgets ||= []
        @widgets.delete_if { |w| w.id == widget.id }
        @widgets << widget
        @widgets.sort_by!(&:priority)
      end

      def widgets_for(profile_user, viewer_user)
        ensure_defaults_registered!
        @widgets.select { |widget| widget.visible?(profile_user, viewer_user) }
      end

      def all_widgets
        ensure_defaults_registered!
        @widgets
      end

      def ensure_defaults_registered!
        return if @defaults_registered

        register(OverviewWidget.new)
        register(ChessStatsWidget.new)
        register(CasinoStatsWidget.new)
        register(AccountSecurityWidget.new)
        register(ActivityLogsWidget.new)

        @defaults_registered = true
      end

      def reset!
        @widgets = []
        @defaults_registered = false
      end
    end
  end
end

