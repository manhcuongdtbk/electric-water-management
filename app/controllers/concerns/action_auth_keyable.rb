module ActionAuthKeyable
  extend ActiveSupport::Concern

  private

  def action_auth_key
    self.class::ACTION_AUTH_KEYS.fetch(action_name) do
      raise ArgumentError, "no auth key for action #{action_name.inspect} in #{self.class.name}"
    end
  end
end
