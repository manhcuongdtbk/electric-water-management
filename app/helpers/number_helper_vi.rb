module NumberHelperVi
  def number_to_vi(number, precision: 2)
    return "" if number.nil?
    rounded = BigDecimal(number.to_s).round(precision, BigDecimal::ROUND_HALF_UP)
    formatted = sprintf("%.#{precision}f", rounded)
    number_with_delimiter(formatted, delimiter: ".", separator: ",")
  end

  def money_to_vi(number)
    return "" if number.nil?
    number_with_delimiter(
      BigDecimal(number.to_s).round(0, BigDecimal::ROUND_HALF_UP).to_i,
      delimiter: "."
    ) + " đ"
  end

  def money_to_vi_plain(number)
    return "" if number.nil?
    number_with_delimiter(
      BigDecimal(number.to_s).round(0, BigDecimal::ROUND_HALF_UP).to_i,
      delimiter: "."
    )
  end
end
