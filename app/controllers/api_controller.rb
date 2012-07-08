class ApiController < BaseController
  rescue_from ::CanCan::AccessDenied,         :with => :error_access_denied
  rescue_from ::ActiveRecord::RecordNotFound, :with => :error_not_found

  before_filter :setup_request, :check_authentication

  attr_reader :current_client

  # **** setup ****

  def setup_request
    set_content_type
  end

  def set_content_type
    if ['json', 'xml', 'msgpack'].include? params[:format].to_s
      response.content_type = "application/#{params[:format]}"
    else
      render_error status: :not_acceptable, message: 'Unsupported format.'
      false
    end
  end

  def set_api_version(version)
    custom_headers api_version: version
  end

  def check_authentication
    if current_access_token
      self.current_user = current_access_token.user
      @current_client   = current_access_token.client
    end
  end

  def setup_ability
    current_access_token.try(:ability) || current_user.ability
  end

  # **** accessors ****

  def current_access_token
    @access_token ||= request.env[Rack::OAuth2::Server::Resource::ACCESS_TOKEN]
  end

  # **** errors *****

  def error_access_denied
    error status: :unauthorized
  end

  def error_not_found
    error status: :not_found
  end

  # **** header helpers ****

  def custom_headers(options)
    options ||= {}
    options.each do |key, value|
      key = key.to_s.camelize.gsub(/[^A-z]+/, '').gsub(/([A-Z])/, '-\1')
      response.headers["X-OM#{key}"] = value.to_s
    end
  end

  def self.api_version(value)
    before_filter do
      set_api_version value
    end
  end
end