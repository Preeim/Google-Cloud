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

      if amount <= 0
        respond_to do |format|
          format.json { render json: { success: false, error: "A tétnek pozitív számnak kell lennie." }, status: :unprocessable_entity }
          format.html { redirect_to table_path(@table), alert: "A tétnek pozitív számnak kell lennie." }
        end
        return
      end

      res = Casino::TableManager.place_bet(@table, current_casino_profile, bet_type, amount)

      respond_to do |format|
        format.json do
          if res[:success]
            render json: { success: true, chips: current_casino_profile.reload.chips, bet: res[:bet], seconds_remaining: res[:seconds_remaining] }
          else
            render json: res, status: :unprocessable_entity
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

    def action
      act = params[:player_action].to_s.downcase.strip
      unless %w[hit stand double].include?(act)
        respond_to do |format|
          format.json { render json: { success: false, error: "Érvénytelen lépés." }, status: :unprocessable_entity }
          format.html { redirect_to table_path(@table), alert: "Érvénytelen lépés." }
        end
        return
      end

      res = Casino::TableManager.player_action(@table, current_casino_profile, act)

      respond_to do |format|
        format.json { render json: res }
        format.html do
          if res[:success]
            act_text = case act
                       when 'hit' then 'Lapot kértél'
                       when 'double' then 'Megdupláztad a tétet (+1 lap)'
                       else 'Megálltál'
                       end
            redirect_to table_path(@table), notice: "Döntésed rögzítve: #{act_text}."
          else
            redirect_to table_path(@table), alert: res[:error]
          end
        end
      end
    end

    def spin
      # Csak admin, a körben aktív téttel rendelkező játékos, vagy lejárt fogadási időzítő esetén indítható el
      has_active_bet = @table.current_bets.where(casino_profile_id: current_casino_profile.id).exists?
      timer_expired = @table.betting_closes_at.present? && @table.betting_closes_at <= Time.current
      unless current_user.admin? || has_active_bet || timer_expired
        respond_to do |format|
          format.json { render json: { success: false, error: "Nincs aktív téted ezen az asztalon a sorsolás indításához." }, status: :forbidden }
          format.html { redirect_to table_path(@table), alert: "Nincs aktív téted ezen az asztalon a sorsolás indításához." }
        end
        return
      end

      res = Casino::TableManager.resolve_round(@table)


      respond_to do |format|
        format.json do
          render json: res
        end
        format.html do
          if res[:success]
            if @table.game_type == "blackjack" && @table.state == "player_turns"
              redirect_to table_path(@table), notice: "A kártyák kiosztva! Döntsd el a felületen: kérsz még lapot (Hit) vagy megállsz (Stand)!"
            else
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
            end
          else
            if res[:idle] || res[:error] == "Nincs aktív tét az asztalon."
              redirect_to table_path(@table), notice: "A fogadási idő lejárt. Tegyél egy tétet a játék megkezdéséhez!"
            else
              redirect_to table_path(@table), alert: res[:error]
            end
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

