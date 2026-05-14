require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

# Build tailwind.css BEFORE Rails boots so Propshaft's load path cache includes it.
# The file is gitignored; we call the binary directly to avoid a full Rails process fork.
unless File.exist?(File.expand_path("../app/assets/builds/tailwind.css", __dir__))
  require "tailwindcss/ruby"
  root = File.expand_path("..", __dir__)
  system(
    Tailwindcss::Ruby.executable,
    "-i", "#{root}/app/assets/tailwind/application.css",
    "-o", "#{root}/app/assets/builds/tailwind.css",
    out: $stdout, err: $stderr
  ) || abort("tailwindcss build failed — run: bin/rails tailwindcss:build")
end

require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require "test_prof/recipes/rspec/let_it_be"

Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
