# frozen_string_literal: true

module Casino
  class Scheduler
    @thread = nil
    @running = false

    def self.start!
      return if @running

      @running = true
      @thread = Thread.new do
        Rails.logger.info "[Casino::Scheduler] Background auto-resolution worker started."
        while @running
          begin
            ActiveRecord::Base.connection_pool.with_connection do
              tick!
            end
          rescue StandardError => e
            Rails.logger.error "[Casino::Scheduler] Error in tick: #{e.message}"
          end
          sleep 2
        end
      end
    end

    def self.stop!
      @running = false
      @thread&.kill
      @thread = nil
    end

    def self.running?
      @running && @thread&.alive?
    end

    def self.tick!
      return unless ActiveRecord::Base.connection.table_exists?("casino_tables")

      tables = Casino::Table.active.where("betting_closes_at IS NOT NULL AND betting_closes_at <= ?", Time.current)
      tables.find_each do |table|
        if table.state == "betting" || table.state == "player_turns"
          Casino::TableManager.resolve_round(table)
        end
      end
    end
  end
end

