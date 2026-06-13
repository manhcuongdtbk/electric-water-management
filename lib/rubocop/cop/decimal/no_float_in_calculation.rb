# frozen_string_literal: true

module RuboCop
  module Cop
    module Decimal
      # Chặn ép kiểu float trong tầng tính toán tiền/điện. AGENTS: dùng BigDecimal,
      # không dùng float cho tiền và điện. `.to_f` / `Float(...)` chỉ hợp lệ ở ranh
      # giới hiển thị/xuất Excel (axlsx, helper) — phạm vi giới hạn ở `.rubocop.yml`
      # (Include app/models, app/services). Xem ADR-031.
      #
      # @example
      #   # bad
      #   total.to_f
      #   Float(total)
      #
      #   # good
      #   BigDecimal(total.to_s)
      class NoFloatInCalculation < Base
        MSG = "Use BigDecimal, not float, in calculation code (AGENTS); " \
              ".to_f/Float() belong at the display boundary only."

        # `x.to_f` hoặc `Float(x)`
        def_node_matcher :float_coercion?, <<~PATTERN
          {(send _ :to_f) (send nil? :Float ...)}
        PATTERN

        def on_send(node)
          return unless float_coercion?(node)

          add_offense(node.loc.selector)
        end
      end
    end
  end
end
