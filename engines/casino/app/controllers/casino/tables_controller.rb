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
            render json: { success: true, chips: current_casino_profile.reload.chips, bet: res[:bet], seconds_remaining: res[:seconds_remaining] }
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
            outcome_text = case @table.game_type
                           when "roulette"
                             num = res[:outcome][:winning_number]
                             col = res[:outcome][:color] == 'red' ? 'Piros' : (res[:outcome][:color] == 'black' ? 'Fekete' : 'Zöld (0)')
                             "Nyertes szám: #{num} (#{col})"
                           when "baccarat"
                             outcome = res[:outcome][:result].to_s.upcase
                             p_score = res[:outcome][:player_score]
                             b_score = res[:outcome][:banker_score]
                             "Eredmény: #{outcome} (Játékos: #{p_score} | Bankár: #{b_score})"
                           when "blackjack"
                             d_score = res[:outcome][:dealer_score]
                             "Osztó pontszáma: #{d_score}"
                           else
                             res[:outcome].to_s
                           end
            redirect_to table_path(@table), notice: "A kör sikeresen lezárult! #{outcome_text}"
          else
            redirect_to table_path(@table), alert: res[:error]
          end
        end
      end
    end

    private

    def set_table
      @table = Casino::Table.find_by(slug: params[:id]) || Casino::Table.find_by(id: params[:id])
      raise ActiveRecord::RecordNotFound, "Nem található kaszinó asztal a megadott azonosítóval (#{params[:id]})." unless @table
    end
  end
end

