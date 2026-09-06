module Casino
  module Admin
    class TablesController < BaseController
      before_action :set_table, only: [:toggle, :reset_round]

      def index
        @tables = Casino::Table.all.order(:game_type, :name)
      end

      def toggle
        new_state = @table.state == "maintenance" ? "idle" : "maintenance"
        @table.update!(state: new_state)
        Casino::TableChannel.broadcast_to(@table, {
          type: "table_state_changed",
          state: new_state,
          message: new_state == "maintenance" ? "Az asztal karbantartás miatt ideiglenesen leállt." : "Az asztal újra aktív."
        })
        flash[:notice] = "A(z) #{@table.name} asztal állapota mostantól: #{new_state.upcase}."
        redirect_to admin_tables_path
      end

      def reset_round
        refunded_count = 0
        @table.with_lock do
          pending_bets = @table.bets.where(round_number: @table.round_number, status: "pending").includes(:profile)
          pending_bets.each do |bet|
            bet.profile.add_chips!(
              bet.amount,
              transaction_type: "refund",
              game_type: @table.game_type,
              metadata: { reason: "admin_round_reset", table_id: @table.id, round_number: @table.round_number }
            )
            bet.update!(status: "canceled")
            refunded_count += 1
          end

          @table.update!(state: "idle", betting_closes_at: nil, state_data: {}.to_json)
        end

        Casino::TableChannel.broadcast_to(@table, {
          type: "round_canceled",
          message: "A kört az adminisztrátor újraindította. A leadott tétek visszatérítésre kerültek."
        })

        flash[:notice] = "A(z) #{@table.name} asztal köre sikeresen visszaállítva (#{refunded_count} tét visszatérítve)."
        redirect_to admin_tables_path
      end

      private

      def set_table
        @table = Casino::Table.find_by(slug: params[:id]) || Casino::Table.find_by(id: params[:id])
        raise ActiveRecord::RecordNotFound, "Nem található asztal (#{params[:id]})." unless @table
      end
    end
  end
end

