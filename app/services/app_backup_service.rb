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

  def build_payload(timestamp)
    payload = {
      metadata: {
        app_slug: @app.slug,
        app_name: @app.name,
        mount_path: @app.mount_path,
        state_before_backup: @app.state,
        backup_created_at: Time.current.iso8601,
        created_by: @actor ? { id: @actor.id, username: @actor.username, email: @actor.email } : "System"
      },
      app_definition: @app.as_json,
      permissions: @app.user_app_permissions.as_json,
      data: {}
    }

    # Modul-specifikus adatbázis táblák mentése
    case @app.slug
    when "chess"
      if defined?(Chess::Match)
        matches = Chess::Match.all.map do |m|
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
        profiles = Casino::Profile.includes(:user).all.map do |p|
          p.as_json.merge("username" => p.user.username)
        end
        bets = defined?(Casino::Bet) ? Casino::Bet.all.as_json : []
        transactions = defined?(Casino::Transaction) ? Casino::Transaction.all.as_json : []
        payload[:data][:profiles] = profiles
        payload[:data][:bets] = bets
        payload[:data][:transactions] = transactions
        payload[:metadata][:records_count] = profiles.size + bets.size + transactions.size
      end
    else
      payload[:metadata][:records_count] = 0
    end

    payload
  end
end

