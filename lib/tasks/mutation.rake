# frozen_string_literal: true

# Mutation testing for the billing/electricity core (ADR-056, Issue #358).
# Run manually / periodically — NOT part of the per-PR `tests` job.
#
#   bin/docker exec app bash -lc "RAILS_ENV=test bundle exec rake mutation:core"
#   bin/docker exec app bash -lc "RAILS_ENV=test bundle exec rake 'mutation:core[loss_calculator]'"
#
# Run on a clean git tree: the runner restores files via `ensure`, but a hard
# kill mid-run can leave a subject mutated — `git checkout -- app/services` recovers.
namespace :mutation do
  desc "Mutation-test the billing core (optional [subject] = source basename without .rb)"
  task :core, [:subject] => :environment do |_t, args|
    require Rails.root.join("lib/mutation/runner")

    config = YAML.load_file(Rails.root.join("config/mutation.yml")).fetch("subjects")
    ignores = (YAML.load_file(Rails.root.join("config/mutation_ignores.yml")) || {}).fetch("ignores", []) || []

    config = config.select { |s| File.basename(s["path"], ".rb") == args[:subject] } if args[:subject]
    abort("No matching subject for #{args[:subject].inspect}") if config.empty?

    subjects = config.map { |s| Mutation::Subject.new(path: s.fetch("path"), spec_paths: s.fetch("specs")) }
    report = Mutation::Runner.new(subjects: subjects, ignores: ignores).run

    puts report
    exit(1) unless report.clean?
  end
end
