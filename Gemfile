source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"

# Auth & authorization
gem "devise"
gem "cancancan"

# Audit trail
gem "paper_trail"

# Charts
gem "chartkick"

# Pagination
gem "pagy"

# Search/filter
gem "ransack"

# Rate limiting
gem "rack-attack", "~> 6.7"

# CSS
gem "tailwindcss-rails"

# Excel/CSV parsing (used by ImportFeb2026Service and future month imports on production)
gem "roo", "~> 2.10"
gem "csv" # roo loads roo/csv which requires csv; csv is no longer a default gem in Ruby 3.4+

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false

  # Testing
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "shoulda-matchers"
  gem "capybara"
  gem "selenium-webdriver"
end

group :development do
  gem "web-console"
end
