# ==============================================================================
# Bánk's Repository - Admin Adatbázis Böngésző (Admin::DatabaseController)
# ==============================================================================
# Vizuális MySQL tábla-kezelő az adminisztrációs felületen.
# Funkciók: tábla-lista statisztikákkal, rekord-böngészés lapozással/szűréssel,
#           CSV és JSON export.
#
# Biztonsági rétegek:
#   - require_admin! (örökli BaseController-ből)
#   - Táblanév whitelist validáció (csak [a-z0-9_] karakterek)
#   - Paraméteres lekérdezések (SQL injection védelem)
#   - Rekord limit: max 50 sor/oldal
# ==============================================================================

require "csv"

module Admin
  class DatabaseController < BaseController
    ROWS_PER_PAGE = 50
    MAX_EXPORT_ROWS = 5000

    # Érzékeny táblák – figyelmeztető ikon jelenik meg mellettük
    SENSITIVE_TABLES = %w[users active_sessions audit_logs].freeze

    # GET /bank-admin/database
    # Összes tábla listája statisztikákkal (INFORMATION_SCHEMA alapján)
    def index
      db_name = ActiveRecord::Base.connection.current_database
      raw = ActiveRecord::Base.connection.exec_query(<<~SQL, "Admin DB Index")
        SELECT
          TABLE_NAME        AS table_name,
          TABLE_ROWS        AS row_count,
          ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 3) AS size_mb,
          CREATE_TIME       AS created_at,
          UPDATE_TIME       AS updated_at,
          TABLE_COMMENT     AS comment
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = #{ActiveRecord::Base.connection.quote(db_name)}
        ORDER BY TABLE_NAME ASC
      SQL

      @tables = raw.map do |row|
        {
          name:       row["table_name"],
          row_count:  row["row_count"].to_i,
          size_mb:    row["size_mb"].to_f,
          created_at: row["created_at"],
          updated_at: row["updated_at"],
          comment:    row["comment"].presence || "",
          sensitive:  SENSITIVE_TABLES.include?(row["table_name"])
        }
      end

      @total_size_mb = @tables.sum { |t| t[:size_mb] }
      @total_records = @tables.sum { |t| t[:row_count] }
    end

    # GET /bank-admin/database/:table
    # Adott tábla rekordjainak megjelenítése szűréssel és lapozással
    def show
      @table_name = sanitize_table_name!(params[:table])
      return unless @table_name

      @page     = [params[:page].to_i, 1].max
      @search   = params[:search].to_s.strip
      @sort_col = sanitize_column_name(params[:sort])
      @sort_dir = params[:dir]&.upcase == "DESC" ? "DESC" : "ASC"

      # Oszloplista az aktuális táblához
      @columns = ActiveRecord::Base.connection.columns(@table_name).map(&:name)

      # Rendezési oszlop – csak létező oszlop lehet
      @sort_col = @columns.first if @sort_col.blank? || !@columns.include?(@sort_col)

      # Összes sor száma (szűréssel)
      count_sql, bind_vals = build_query(@table_name, @search, @columns)
      @total_count = ActiveRecord::Base.connection.exec_query(
        "SELECT COUNT(*) AS cnt FROM (#{count_sql}) AS sub", "Admin DB Count", bind_vals
      ).first["cnt"].to_i

      @total_pages = [(@total_count.to_f / ROWS_PER_PAGE).ceil, 1].max
      @page = [@page, @total_pages].min

      # Rekordok lekérdezése
      offset = (@page - 1) * ROWS_PER_PAGE
      quoted_sort = ActiveRecord::Base.connection.quote_column_name(@sort_col)
      records_sql = "#{count_sql} ORDER BY #{quoted_sort} #{@sort_dir} LIMIT #{ROWS_PER_PAGE} OFFSET #{offset}"
      @records = ActiveRecord::Base.connection.exec_query(records_sql, "Admin DB Records", bind_vals)

      @sensitive = SENSITIVE_TABLES.include?(@table_name)
    end

    # GET /bank-admin/database/:table/export?format=csv|json
    # Export CSV vagy JSON formátumban (max MAX_EXPORT_ROWS sor)
    def export
      @table_name = sanitize_table_name!(params[:table])
      return unless @table_name

      @columns = ActiveRecord::Base.connection.columns(@table_name).map(&:name)
      base_sql, bind_vals = build_query(@table_name, params[:search].to_s.strip, @columns)
      full_sql = "#{base_sql} ORDER BY #{ActiveRecord::Base.connection.quote_column_name(@columns.first)} DESC LIMIT #{MAX_EXPORT_ROWS}"

      records = ActiveRecord::Base.connection.exec_query(full_sql, "Admin DB Export", bind_vals)
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")

      respond_to do |format|
        format.csv do
          headers["Content-Disposition"] = "attachment; filename=\"#{@table_name}_#{timestamp}.csv\""
          headers["Content-Type"] = "text/csv; charset=utf-8"
          output = CSV.generate(headers: true) do |csv|
            csv << records.columns
            records.rows.each { |row| csv << row }
          end
          render plain: output
        end

        format.json do
          headers["Content-Disposition"] = "attachment; filename=\"#{@table_name}_#{timestamp}.json\""
          data = records.map { |row| records.columns.zip(row.values).to_h }
          render json: { table: @table_name, exported_at: Time.current, count: data.size, records: data }
        end
      end
    end

    private

    # Táblanév szigorú sanitálása: csak betű, szám, aláhúzás
    def sanitize_table_name!(name)
      clean = name.to_s.gsub(/[^a-z0-9_]/i, "").downcase
      existing = ActiveRecord::Base.connection.tables

      unless existing.include?(clean)
        redirect_to admin_database_index_path, alert: "A tábla nem található: #{name.inspect}"
        return nil
      end
      clean
    end

    # Oszlopnév sanitálás
    def sanitize_column_name(name)
      name.to_s.gsub(/[^a-z0-9_]/i, "")
    end

    # Szűrési lekérdezés összerakása (LIKE-alapú globális kereső)
    def build_query(table, search, columns)
      quoted_table = ActiveRecord::Base.connection.quote_table_name(table)
      base = "SELECT * FROM #{quoted_table}"

      if search.present?
        conditions = columns.map do |col|
          "CAST(#{ActiveRecord::Base.connection.quote_column_name(col)} AS CHAR) LIKE ?"
        end.join(" OR ")
        bind_vals = columns.map { "%#{search}%" }
        ["#{base} WHERE #{conditions}", bind_vals]
      else
        [base, []]
      end
    end
  end
end
