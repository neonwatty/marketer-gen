# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    
    # Allow scripts from self, https sources, and nonce-based inline scripts
    # unsafe-eval is needed for importmap functionality
    policy.script_src  :self, :https, :unsafe_eval
    
    # Allow styles from self, https sources, inline styles (for Tailwind), and specific CDN sources
    policy.style_src   :self, :https, :unsafe_inline, "https://cdn.jsdelivr.net"
    
    policy.connect_src :self, :https
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self
    
    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles.
  config.content_security_policy_nonce_generator = -> request { 
    SecureRandom.base64(16)
  }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # Report violations without enforcing the policy (disable for production)
  # config.content_security_policy_report_only = true
end
