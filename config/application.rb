require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ElectricWaterManagement
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # `generators` holds Rails generators (lib/generators/**) loaded by the
    # generators lookup, not zeitwerk — ignore so `rails zeitwerk:check` stays
    # green (their constants do not match the lib autoload root). See ADR-051.
    # `mutation` holds the mutation-testing harness (lib/mutation/**), required
    # explicitly by lib/tasks/mutation.rake — keep it off the autoload/eager-load
    # path (test tooling, not app code). See ADR-056, Issue #358.
    config.autoload_lib(ignore: %w[assets tasks rubocop generators mutation])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.

    config.time_zone = "Hanoi"
    config.i18n.default_locale = :vi
    config.i18n.available_locales = [:vi]
    config.encoding = "UTF-8"

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
