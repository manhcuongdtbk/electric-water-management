# frozen_string_literal: true

module RuboCop
  module Cop
    module Decimal
      # Ép làm tròn tiền/điện bằng mode half-up tường minh. AGENTS: ROUND_HALF_UP
      # (5 làm tròn lên), không dùng ROUND_HALF_EVEN/banker's. Mọi `.round` ở tầng
      # tính toán phải kèm `:half_up` hoặc hằng `*ROUND_HALF_UP`. Phạm vi giới hạn ở
      # `.rubocop.yml` (Include app/models, app/services). Xem ADR-031.
      #
      # @example
      #   # bad
      #   amount.round(2)
      #   amount.round(2, :half_even)
      #   amount.round(2, BigDecimal::ROUND_HALF_EVEN)
      #
      #   # good
      #   amount.round(2, :half_up)
      #   amount.round(2, BigDecimal::ROUND_HALF_UP)
      class ExplicitRoundingMode < Base
        MSG = "Round money/electricity with an explicit half-up mode (AGENTS): " \
              "value.round(n, :half_up)."

        def on_send(node)
          return unless node.method?(:round)
          return if half_up_mode?(node)

          add_offense(node.loc.selector)
        end

        private

        def half_up_mode?(node)
          node.arguments.any? do |arg|
            (arg.sym_type? && arg.value == :half_up) ||
              (arg.const_type? && arg.const_name.to_s.end_with?("ROUND_HALF_UP"))
          end
        end
      end
    end
  end
end
