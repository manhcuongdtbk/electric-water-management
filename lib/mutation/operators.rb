# frozen_string_literal: true

require "ripper"
require_relative "change"

module Mutation
  # Generates mutations for a Ruby source string using Ripper's lexer, so we
  # only ever touch real operator / literal / keyword tokens — never the bytes
  # inside string literals or comments.
  module Operators
    # token text => [replacement, label]; applies to :on_op tokens.
    OP_RULES = {
      "+"  => %w[- arithmetic],
      "-"  => %w[+ arithmetic],
      "*"  => %w[/ arithmetic],
      "/"  => %w[* arithmetic],
      "<"  => %w[<= boundary],
      ">"  => %w[>= boundary],
      "<=" => %w[< boundary],
      ">=" => %w[> boundary],
      "==" => %w[!= comparison],
      "!=" => %w[== comparison],
      "&&" => %w[|| logical],
      "||" => %w[&& logical]
    }.freeze

    # keyword / identifier swaps; applies to :on_kw and :on_ident tokens.
    WORD_RULES = {
      "if"      => %w[unless conditional],
      "unless"  => %w[if conditional],
      "half_up" => %w[half_even rounding],
      "zero?"   => %w[nonzero? predicate]
    }.freeze

    module_function

    def changes_for(source, path:)
      changes = []
      Ripper.lex(source).each do |(line, column), type, token, _state|
        rules = rules_for(type, token)
        next unless rules

        rules.each do |to, label|
          changes << Change.new(path: path, line: line, column: column,
                                from: token, to: to, label: label)
        end
      end
      changes
    end

    # Returns an array of [replacement, label] pairs, or nil if the token is not
    # mutable.
    def rules_for(type, token)
      case type
      when :on_op
        op = OP_RULES[token]
        op ? [[op[0], "#{op[1]} #{token}->#{op[0]}"]] : nil
      when :on_kw, :on_ident
        w = WORD_RULES[token]
        w ? [[w[0], "#{w[1]} #{token}->#{w[0]}"]] : nil
      when :on_int
        n = Integer(token, exception: false)
        return nil if n.nil?

        rules = [[(n + 1).to_s, "constant #{token}->#{n + 1}"]]
        rules << ["0", "constant #{token}->0"] unless n.zero? # 0->0 is a no-op
        rules
      when :on_float
        [["0", "constant #{token}->0"]]
      end
    end
  end
end
