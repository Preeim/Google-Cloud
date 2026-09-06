module Casino
  module Admin
    class UsersController < BaseController
      before_action :set_profile, only: [:edit, :update, :reset]

      def index
        @profiles = Casino::Profile.includes(:user).joins(:user).order("users.username ASC")
        if params[:search].present?
          query = "%#{params[:search].downcase}%"
          @profiles = @profiles.where("LOWER(users.username) LIKE ? OR LOWER(users.email) LIKE ?", query, query)
        end
      end

      def edit
        @recent_transactions = @profile.transactions.recent.limit(10)
      end

      def update
        if params[:action_type] == "add"
          amount = params[:amount].to_i
          if amount > 0
            @profile.add_chips!(amount, transaction_type: "admin_adjustment", metadata: { actor: current_user.username })
            ::AuditLog.log!(
              action: "casino_user_chips_added",
              actor: current_user,
              target: @profile.user,
              resource: @profile,
              request: request,
              metadata: { amount: amount, balance_after: @profile.reload.chips, target_username: @profile.user.username }
            ) rescue nil
            flash[:notice] = "Sikeresen hozzáadva #{amount} zseton #{@profile.user.username} számlájához."
          else
            flash[:alert] = "Érvénytelen összeg."
          end
        elsif params[:action_type] == "deduct"
          amount = params[:amount].to_i
          if amount > 0 && @profile.chips >= amount
            @profile.deduct_chips!(amount, transaction_type: "admin_adjustment", metadata: { actor: current_user.username })
            ::AuditLog.log!(
              action: "casino_user_chips_deducted",
              actor: current_user,
              target: @profile.user,
              resource: @profile,
              request: request,
              metadata: { amount: amount, balance_after: @profile.reload.chips, target_username: @profile.user.username }
            ) rescue nil
            flash[:notice] = "Sikeresen levonva #{amount} zseton #{@profile.user.username} számlájáról."
          else
            flash[:alert] = "Érvénytelen összeg vagy nincs elég egyenleg."
          end
        elsif params[:action_type] == "set"
          new_amount = params[:new_amount].to_i
          if new_amount >= 0
            @profile.set_balance!(new_amount, actor: current_user)
            ::AuditLog.log!(
              action: "casino_user_chips_set",
              actor: current_user,
              target: @profile.user,
              resource: @profile,
              request: request,
              metadata: { new_balance: new_amount, target_username: @profile.user.username }
            ) rescue nil
            flash[:notice] = "#{@profile.user.username} zsetonjai sikeresen beállítva: #{new_amount} zseton."
          else
            flash[:alert] = "A zsetonok száma nem lehet negatív."
          end
        end

        redirect_to edit_admin_user_path(@profile)
      end

      def reset
        @profile.reset_to_default!(actor: current_user)
        ::AuditLog.log!(
          action: "casino_user_chips_reset",
          actor: current_user,
          target: @profile.user,
          resource: @profile,
          request: request,
          metadata: { new_balance: 10000, target_username: @profile.user.username }
        ) rescue nil
        flash[:notice] = "#{@profile.user.username} egyenlege sikeresen visszaállítva a kezdő 10 000 zsetonra."
        redirect_to admin_users_path
      end

      private

      def set_profile
        @profile = Casino::Profile.find(params[:id])
      end
    end
  end
end

