class TestController < ApplicationController
  before_action :require_admin!

  def index
    # Test MySQL connection and measure latency
    @db_connected = false
    @db_latency_ms = nil
    @db_error = nil

    begin
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      ActiveRecord::Base.connection.execute("SELECT 1")
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @db_latency_ms = ((end_time - start_time) * 1000).round(2)
      @db_connected = true
      @db_version = ActiveRecord::Base.connection.execute("SELECT VERSION() as v").first&.first rescue "MySQL 8+"
      @db_name = ActiveRecord::Base.connection.current_database rescue "hub_development"
      @users_count = User.count rescue 0
      @recent_users = User.order(created_at: :desc).limit(5) rescue []
    rescue => e
      @db_error = e.message
    end

    # Server environment statistics
    @ruby_version = RUBY_VERSION
    @rails_version = Rails.version
    @server_time = Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")
    @hostname = Socket.gethostname rescue "Google Cloud VM"
  end
end

