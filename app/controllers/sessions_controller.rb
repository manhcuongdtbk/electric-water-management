class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :extend_session ]
  skip_before_action :check_force_password_change!, only: [ :extend_session ]

  def extend_session
    unless user_signed_in?
      head :unauthorized
      return
    end

    warden.session(:user)["last_request_at"] = Time.current.utc.to_i
    head :no_content
  end
end
