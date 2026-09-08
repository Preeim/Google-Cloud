# frozen_string_literal: true

module Casino
  class Scheduler
    LOCK_KEY = "casino:scheduler:leader_lock"
    LOCK_TTL = 6 # seconds
    @thread = nil
    @running = false

    def self.start!
      return if @running

      @running = true
      @thread = Thread.new do
        Rails.logger.info "[Casino::Scheduler] Background auto-resolution worker started on PID #{Process.pid}."
        while @running
          begin
            # Check if this worker process can acquire or renew the leader lock
            if acquire_leader_lock!
              ActiveRecord::Base.connection_pool.with_connection do
                tick!
              end
            end
          rescue StandardError => e
            Rails.logger.error "[Casino::Scheduler] Error in tick loop: #{e.message}"
          end
          sleep 2
        end
      end
    end

    def self.stop!
      @running = false
      release_leader_lock!
      @thread&.kill
      @thread = nil
    end

    def self.running?
      @running && @thread&.alive?
    end

    def self.acquire_leader_lock!
      current_leader = Rails.cache.read(LOCK_KEY)
      my_id = "#{Socket.gethostname rescue 'host'}-#{Process.pid}"

      if current_leader.blank? || current_leader == my_id
        # Write or extend lock
        Rails.cache.write(LOCK_KEY, my_id, expires_in: LOCK_TTL.seconds)
        true
      else
        # Another worker is actively leading
        false
      end
    rescue StandardError => e
      Rails.logger.warn "[Casino::Scheduler] Lock acquisition warning: #{e.message}"
      # Fallback to single-run tick if cache is unavailable in memory
      true
    end

    def self.release_leader_lock!
      my_id = "#{Socket.gethostname rescue 'host'}-#{Process.pid}"
      current_leader = Rails.cache.read(LOCK_KEY)
      Rails.cache.delete(LOCK_KEY) if current_leader == my_id
    rescue StandardError
      nil
    end

    def self.tick!
      return unless ActiveRecord::Base.connection.table_exists?("casino_tables")

      tables = Casino::Table.active.where("betting_closes_at IS NOT NULL AND betting_closes_at <= ?", Time.current)
      tables.find_each do |table|
        begin
          if table.state == "betting" || table.state == "player_turns"
            Casino::TableManager.resolve_round(table)
          end
        rescue StandardError => table_err
          Rails.logger.error "[Casino::Scheduler] Error resolving table #{table.id}: #{table_err.message}"
        end
      end
    end
  end
end

