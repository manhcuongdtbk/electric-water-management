# frozen_string_literal: true

require_relative "change"
require_relative "operators"
require_relative "report"

module Mutation
  Subject = Struct.new(:path, :spec_paths, keyword_init: true)

  # Default spec runner: shells out to RSpec with --fail-fast. Exit 0 => the
  # suite passed under the mutation => the mutant SURVIVED.
  class SystemSpecRunner
    def passes?(spec_paths, _path)
      cmd = ["bundle", "exec", "rspec", *spec_paths, "--fail-fast", "--no-color"]
      system(*cmd, out: File::NULL, err: File::NULL)
    end
  end

  class Runner
    def initialize(subjects:, spec_runner: SystemSpecRunner.new, ignores: [])
      @subjects = subjects
      @spec_runner = spec_runner
      @ignores = ignores.map { |h| normalize(h) }
    end

    def run
      results = []
      ignored_count = 0

      @subjects.each do |subject|
        original = File.read(subject.path)
        changes = Operators.changes_for(original, path: subject.path)

        changes.each do |change|
          if ignored?(change)
            ignored_count += 1
            next
          end

          begin
            File.write(subject.path, apply(original, change))
            survived = @spec_runner.passes?(subject.spec_paths, subject.path)
            results << { change: change, status: survived ? :survived : :killed }
          ensure
            File.write(subject.path, original)
          end
        end
      end

      Report.new(results: results, ignored_count: ignored_count)
    end

    private

    def normalize(hash)
      { "path" => hash["path"], "line" => hash["line"], "from" => hash["from"], "to" => hash["to"] }
    end

    def ignored?(change)
      @ignores.include?(normalize(change.ignore_key))
    end

    # Replace `from` with `to` at the change's 1-based line / 0-based column.
    # Re-derived from the pristine `original` every time, so no offset drift.
    def apply(original, change)
      lines = original.lines
      idx = change.line - 1
      line = lines[idx].dup
      line[change.column, change.from.length] = change.to
      lines[idx] = line
      lines.join
    end
  end
end
