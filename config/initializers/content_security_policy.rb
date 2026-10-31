# frozen_string_literal: true

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https, "wss://bankrepo.hu", "ws://bankrepo.hu", "wss://www.bankrepo.hu"
    policy.frame_ancestors :self
    policy.form_action :self
    policy.base_uri :self
  end

  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)
end
