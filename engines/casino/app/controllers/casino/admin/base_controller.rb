module Casino
  module Admin
    class BaseController < Casino::ApplicationController
      before_action :require_admin!
      layout "casino/admin"
    end
  end
end

