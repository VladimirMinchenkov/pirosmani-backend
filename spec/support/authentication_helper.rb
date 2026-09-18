# spec/support/authentication_helper.rb
module AuthenticationHelper
  def auth_headers(admin_user)
    { 'Authorization' => "Bearer #{admin_user.access_token}" }
  end

  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
end