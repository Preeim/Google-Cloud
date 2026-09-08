# ==============================================================================
# Bánk's Repository - Modul Biztonsági Mentés Szolgáltatás (AppBackupService)
# ==============================================================================
# Felelős egy adott modul (pl. Sakk) összes adatbázis-rekordjának és konfigurációjának
# strukturált JSON exportálásáért a szerver háttértárára (storage/backups/).
# Automatikusan lefut, amikor egy adminisztrátor inaktiválja (kikapcsolja) a modult.
# ==============================================================================

class AppBackupService
  BACKUP_DIR = Rails.root.join("storage", "backups")

  def self.export!(app_definition, actor: nil)
    new(app_definition, actor: actor).export!
  end

  def initialize(app_definition, actor: nil)
    @app = app_definition
    @actor = actor
  end

  def export!
    FileUtils.mkdir_p(BACKUP_DIR)

    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "#{@app.slug}_backup_#{timestamp}.json"
    file_path = BACKUP_DIR.join(filename)

    export_payload = build_payload(timestamp)

    File.open(file_path, "w") do |f|
      f.write(JSON.pretty_generate(export_payload))
    end

    {
      success: true,
      filename: filename,
      file_path: file_path.to_s,
      size_bytes: File.size(file_path),
      created_at: Time.current
    }
  rescue => e
    Rails.logger.error("[AppBackupService] Mentési hiba (#{@app.slug}): #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  private

  MAX_BACKUP_RECORDS_PER_TABLE = 10_000

  def safe_export_records(scope, limit: MAX_BACKUP_RECORDS_PER_TABLE)
    return [] unless scope
    records = []
    scope.order(id: :desc).limit(limit).each do |rec|
      records << (block_given? ? yield(rec) : rec.as_json)
    end
    records
  end

  def build_payload(timestamp)
    payload = {
      metadata: {
        app_slug: @app.slug,
        app_name: @app.name,
        mount_path: @app.mount_path,
        state_before_backup: @app.state,
        backup_created_at: Time.current.iso8601,
        created_by: @actor ? { id: @actor.id, username: @actor.username, email: @actor.email } : "System",
        max_records_per_table: MAX_BACKUP_RECORDS_PER_TABLE
      },
      app_definition: @app.as_json,
      permissions: @app.user_app_permissions.as_json,
      data: {}
    }

    # Modul-specifikus adatbázis táblák mentése (memóriatakarékos, kötegelt lekérdezéssel)
    case @app.slug
    when "chess"
      if defined?(Chess::Match)
        matches = safe_export_records(Chess::Match.includes(:white_player, :black_player)) do |m|
          m.as_json.merge(
            "white_player" => m.white_player_name,
            "black_player" => m.black_player_name
          )
        end
        payload[:data][:matches] = matches
        payload[:metadata][:records_count] = matches.size
      end
    when "casino"
      if defined?(Casino::Profile)
        profiles = safe_export_records(Casino::Profile.includes(:user)) do |p|
          p.as_json.merge("username" => p.user&.username)
        end
        bets = defined?(Casino::Bet) ? safe_export_records(Casino::Bet) : []
        transactions = defined?(Casino::Transaction) ? safe_export_records(Casino::Transaction) : []
        payload[:data][:profiles] = profiles
        payload[:data][:bets] = bets
        payload[:data][:transactions] = transactions
        payload[:metadata][:records_count] = profiles.size + bets.size + transactions.size
      end
    when "canvas"
      if defined?(Canvas::Board)
        boards = safe_export_records(Canvas::Board)
        strokes = defined?(Canvas::Stroke) ? safe_export_records(Canvas::Stroke) : []
        payload[:data][:boards] = boards
        payload[:data][:strokes] = strokes
        payload[:metadata][:records_count] = boards.size + strokes.size
      end
    else
      payload[:metadata][:records_count] = 0
    end

    payload
  end
end

