module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    protected

    def find_verified_user
      # Allow connection even if guest for test dashboard
      user_id = cookies.encrypted[Rails.application.config.session_options[:key]]&.[]("user_id") rescue nil
      User.find_by(id: user_id) if user_id
    end
  end
end
