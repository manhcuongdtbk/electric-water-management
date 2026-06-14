# frozen_string_literal: true

module Mutation
  # One mutation: replace `from` with `to` at a 1-based line / 0-based column.
  # `label` groups mutations by operator for reporting (e.g. "arithmetic +->-").
  Change = Struct.new(:path, :line, :column, :from, :to, :label, keyword_init: true) do
    def location
      "#{path}:#{line}"
    end

    def description
      "#{from} -> #{to}  (#{label})"
    end

    # Stable key for the ignore-list (equivalent mutants).
    def ignore_key
      { "path" => path, "line" => line, "from" => from, "to" => to }
    end
  end
end
