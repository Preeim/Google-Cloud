module Casino
  class TablesController < ApplicationController
    before_action :set_table

    def show
      @current_bets = @table.current_bets.includes(profile: :user).order(created_at: :desc)
      @state_data = @table.current_state_data
      @my_bets = @table.current_bets.where(profile: current_casino_profile)
    end

    def bet
      bet_type = params[:bet_type]
      amount = params[:amount].to_i

      res = Casino::TableManager.place_bet(@table, current_casino_profile, bet_type, amount)

      respond_to do |format|
        format.json do
          if res[:success]
            render json: { success: true, chips: current_casino_profile.reload.chips, bet: res[:bet] }
          else
            render json: { success: false, error: res[:error] }, status: :unprocessable_entity
          end
        end
        format.html do
          if res[:success]
            redirect_to table_path(@table), notice: "Sikeres tét: #{amount} zseton a következőre: #{bet_type}."
          else
            redirect_to table_path(@table), alert: res[:error]
          end
        end
      end
    end

    def spin
      res = Casino::TableManager.resolve_round(@table)

      respond_to do |format|
        format.json do
          render json: res
        end
        format.html do
          if res[:success]
            redirect_to table_path(@table), notice: "A kör lezárult! Eredmény: #{res[:outcome]}"
          else
            redirect_to table_path(@table), alert: res[:error]
          end
        end
      end
    end

    private

    def set_table
      @table = Casino::Table.find_by!(slug: params[:id])
    end
  end
end

