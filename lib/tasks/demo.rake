namespace :demo do
  desc "Load the curated demo dataset (db/seeds/demo.rb) into the current DB"
  task seed: :environment do
    load Rails.root.join("db", "seeds", "demo.rb")
  end
end
