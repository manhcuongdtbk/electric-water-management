module DecimalHelpers
  def display_value(value)
    BigDecimal(value.to_s).round(2, BigDecimal::ROUND_HALF_UP)
  end

  RSpec::Matchers.define :eq_display do |expected_string|
    match do |actual|
      next false if actual.nil?
      actual.round(2, BigDecimal::ROUND_HALF_UP) == BigDecimal(expected_string.to_s)
    end

    failure_message do |actual|
      "Mong: #{expected_string} (làm tròn hiển thị 2 chữ số), nhận: #{actual&.round(2, BigDecimal::ROUND_HALF_UP)} (giá trị thô: #{actual.inspect})"
    end
  end

  RSpec::Matchers.define :eq_money do |expected_integer|
    match do |actual|
      next false if actual.nil?
      actual.round(0, BigDecimal::ROUND_HALF_UP) == BigDecimal(expected_integer.to_s)
    end

    failure_message do |actual|
      "Mong: #{expected_integer} đồng (làm tròn 0 chữ số), nhận: #{actual&.round(0, BigDecimal::ROUND_HALF_UP)} (giá trị thô: #{actual.inspect})"
    end
  end
end
