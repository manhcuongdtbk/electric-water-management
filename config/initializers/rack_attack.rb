class Rack::Attack
  throttle("logins/ip", limit: 5, period: 60.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("sessions_extend/ip", limit: 60, period: 60.seconds) do |req|
    req.ip if req.path == "/sessions/extend" && req.post?
  end

  blocklist("block_probing") do |req|
    [
      "/.env", "/wp-admin", "/wp-login.php", "/.git/config",
      "/admin.php", "/phpMyAdmin"
    ].any? { |path| req.path.start_with?(path) }
  end

  self.throttled_responder = ->(_request) {
    [ 429, { "Content-Type" => "text/plain" }, [ "Retry later.\n" ] ]
  }
end
