module Chess
  module Admin
    class MatchesController < BaseController
      before_action :set_match, only: [:show, :abort, :destroy]

      def index
        @matches = Match.all

        if params[:status].present? && %w[pending active completed aborted].include?(params[:status])
          @matches = @matches.where(status: params[:status])
        end

        if params[:q].present?
          term = "%#{params[:q].strip}%"
          @matches = @matches.where('uuid LIKE ?', term)
        end

        @matches = @matches.order(created_at: :desc).limit(100)
      end

      def show
      end

      def abort
        if @match.pending? || @match.active?
          @match.update!(status: 'aborted', termination_reason: 'resign')
          Chess::MatchChannel.broadcast_to(@match, { action: 'game_over', reason: 'A játszmát a rendszergazda leállította.' })
          flash[:notice] = \"A(z) Match ##{@match.uuid.split('-').first} játszma megszakítva.\"
        else
          flash[:alert] = 'Ez a játszma már korábban lezárult.'
        end
        redirect_back(fallback_location: admin_matches_path)
      end

      def destroy
        uuid_short = @match.uuid.split('-').first
        @match.destroy
        flash[:notice] = \"A(z) Match ##{uuid_short} sikeresen törölve az adatbázisból.\"
        redirect_to admin_matches_path
      end

      def cleanup_pending
        cutoff = Setting.current.auto_abort_minutes.minutes.ago
        expired_matches = Match.where(status: 'pending').where('created_at < ?', cutoff)
        count = expired_matches.count
        expired_matches.destroy_all

        flash[:notice] = \"#{count} darab #{Setting.current.auto_abort_minutes} percnél régebbi várakozó kihívás sikeresen törölve!\"
        redirect_to admin_matches_path
      end

      private

      def set_match
        @match = Match.find_by!(uuid: params[:id])
      end
    end
  end
end
