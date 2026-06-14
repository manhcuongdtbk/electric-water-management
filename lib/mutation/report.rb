# frozen_string_literal: true

module Mutation
  # Aggregates runner results into counts and a human-readable summary.
  # `results` is an array of { change: Mutation::Change, status: :killed | :survived }.
  class Report
    attr_reader :results, :ignored

    def initialize(results:, ignored_count:)
      @results = results
      @ignored = ignored_count
    end

    def total = results.size
    def killed = results.count { |r| r[:status] == :killed }
    def survived = results.count { |r| r[:status] == :survived }
    def survivors = results.select { |r| r[:status] == :survived }.map { |r| r[:change] }
    def clean? = survived.zero?

    def to_s
      lines = []
      lines << "Mutation testing — billing core"
      lines << "  TOTAL:    #{total}"
      lines << "  KILLED:   #{killed}"
      lines << "  SURVIVED: #{survived}"
      lines << "  IGNORED:  #{ignored} (equivalent mutants)"
      unless survivors.empty?
        lines << ""
        lines << "Survivors (assertions to strengthen):"
        survivors.each { |c| lines << "  #{c.location}  #{c.description}" }
      end
      lines.join("\n")
    end
  end
end
