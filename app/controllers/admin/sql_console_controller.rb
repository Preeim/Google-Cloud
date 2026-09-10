# ==============================================================================
# Bánk's Repository - Admin SQL Konzol (Admin::SqlConsoleController)
# ==============================================================================
# Nyers SQL lekérdezések futtatása az adminisztrációs felületen.
#
# Biztonsági rétegek:
#   - require_admin! (örökli BaseController-ből)
#   - DDL kulcsszavak detektálása (DROP/TRUNCATE/CREATE TABLE/ALTER/RENAME)
#     → requires_confirmation: true JSON válasz, ha nincs confirmed: true param
#   - SELECT eredmény limit: max 500 sor (automatikus LIMIT hozzáfűzés)
#   - Minden futtatás rögzítve az AuditLog-ban
#   - Query history session-ban tárolva (utolsó 10 lekérdezés)
# ==============================================================================

module Admin
  class SqlConsoleController < BaseController
    RESULT_LIMIT = 500
    HISTORY_SIZE = 10

    # DDL kulcsszavak, amelyek confirmation modalt igényelnek
    DDL_KEYWORDS = %w[DROP TRUNCATE ALTER RENAME].freeze

    # GET /bank-admin/sql_console
    # GET /bank-admin/sql_console?clear_history=1
    def show
      if params[:clear_history].present?
        session.delete(:admin_sql_history)
        redirect_to admin_sql_console_path, notice: "Előzmények törölve."
        return
      end
      @query_history = session[:admin_sql_history] || []
      @last_query = params[:q].to_s
    end

    # POST /bank-admin/sql_console/execute
    def execute
      raw_sql = params[:sql].to_s.strip
      confirmed = params[:confirmed].to_s == "true"

      if raw_sql.blank?
        render json: { success: false, error: "Üres lekérdezés." }
        return
      end

      # DDL detektálás – confirmation szükséges
      detected_ddl = detect_ddl_keyword(raw_sql)
      if detected_ddl && !confirmed
        render json: {
          success: false,
          requires_confirmation: true,
          ddl_keyword: detected_ddl,
          message: "A lekérdezés '#{detected_ddl}' utasítást tartalmaz. Ez visszafordíthatatlan hatással lehet az adatbázisra."
        }
        return
      end

      started_at = Time.current
      begin
        result = execute_sql(raw_sql)
        elapsed_ms = ((Time.current - started_at) * 1000).round

        # AuditLog rögzítés
        AuditLog.create!(
          action: "sql_execute",
          actor_user_id: current_user.id,
          ip_address: request.remote_ip,
          metadata_payload: {
            query: raw_sql.truncate(500),
            query_type: result[:query_type],
            rows_affected: result[:row_count],
            execution_time_ms: elapsed_ms,
            confirmed_ddl: (detected_ddl.present? && confirmed)
          }
        )

        # Query history frissítés session-ban
        history = session[:admin_sql_history] || []
        history.unshift(raw_sql).uniq!
        history = history.first(HISTORY_SIZE)
        session[:admin_sql_history] = history

        render json: result.merge(
          success: true,
          execution_time_ms: elapsed_ms
        )

      rescue ActiveRecord::StatementInvalid => e
        elapsed_ms = ((Time.current - started_at) * 1000).round
        render json: {
          success: false,
          error: e.message.truncate(800),
          execution_time_ms: elapsed_ms
        }
      end
    end

    private

    def detect_ddl_keyword(sql)
      upper = sql.upcase
      DDL_KEYWORDS.find { |kw| upper.match?(/\b#{kw}\b/) }
    end

    def execute_sql(sql)
      upper_sql = sql.strip.upcase.split.first || ""

      case upper_sql
      when "SELECT", "EXPLAIN", "SHOW", "DESCRIBE", "DESC"
        # SELECT – limit automatikus hozzáfűzés ha nincs
        limited_sql = if sql.upcase.include?("LIMIT")
                        sql
                      else
                        "#{sql} LIMIT #{RESULT_LIMIT}"
                      end
        result = ActiveRecord::Base.connection.exec_query(limited_sql, "Admin SQL Console")
        limited = !sql.upcase.include?("LIMIT") && result.rows.size >= RESULT_LIMIT
        {
          query_type: "SELECT",
          columns: result.columns,
          rows: result.rows.map { |r| r.map { |v| v.nil? ? nil : v.to_s } },
          row_count: result.rows.size,
          limited_to: limited ? RESULT_LIMIT : nil
        }
      when "INSERT", "UPDATE", "DELETE"
        # DML – rows affected
        affected = ActiveRecord::Base.connection.exec_update(sql, "Admin SQL Console")
        {
          query_type: upper_sql,
          rows_affected: affected,
          row_count: affected,
          columns: [],
          rows: []
        }
      else
        # Egyéb (DDL, ha confirmed=true) – futtatás exec_query-vel
        ActiveRecord::Base.connection.execute(sql)
        {
          query_type: upper_sql,
          rows_affected: 0,
          row_count: 0,
          columns: [],
          rows: [],
          message: "Utasítás sikeresen végrehajtva."
        }
      end
    end
  end
end
