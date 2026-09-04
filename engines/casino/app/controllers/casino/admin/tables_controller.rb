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
        flash[:notice] = "A(z) #{@table.name} asztal állapota mostantól: #{new_state.upcase}."
        redirect_to admin_tables_path
      end

      def reset_round
        @table.bets.where(round_number: @table.round_number, status: "pending").update_all(status: "canceled")
        @table.update!(state: "idle", betting_closes_at: nil)
        flash[:notice] = "A(z) #{@table.name} asztal köre sikeresen visszaállítva."
        redirect_to admin_tables_path
      end

      private

      def set_table
        @table = Casino::Table.find(params[:id])
      end
    end
  end
end

