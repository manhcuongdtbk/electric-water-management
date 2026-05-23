# Helper để parse xlsx response trong test.
# Dùng Zip + Nokogiri (đã có sẵn) — không cần thêm gem.
module XlsxHelpers
  # Parse xlsx response body thành struct chứa rows, formulas, merges.
  # Trả về OpenStruct:
  #   .rows          — Array of Arrays (giá trị mỗi ô, string hoặc number)
  #   .formulas      — Hash { "A6" => "=SUM(F6:L6)" } (cell ref → formula string)
  #   .merges         — Array of Strings ["A3:K3", "L3:N3", ...]
  #   .shared_strings — Array of Strings (lookup table cho string values)
  #   .column_count   — Integer (số cột row dài nhất)
  def parse_xlsx(response_body)
    require "zip"
    require "nokogiri"

    sheets = {}
    Zip::InputStream.open(StringIO.new(response_body)) do |zip|
      while (entry = zip.get_next_entry)
        sheets[entry.name] = zip.read if entry.name =~ /sheet1\.xml|sharedStrings\.xml/
      end
    end

    shared_strings = []
    if sheets["xl/sharedStrings.xml"]
      ss_doc = Nokogiri::XML(sheets["xl/sharedStrings.xml"])
      ss_doc.remove_namespaces!
      shared_strings = ss_doc.xpath("//si").map { |si| si.xpath(".//t").map(&:text).join }
    end

    doc = Nokogiri::XML(sheets["xl/worksheets/sheet1.xml"])
    doc.remove_namespaces!

    rows = []
    formulas = {}
    doc.xpath("//row").each do |row_node|
      row_idx = row_node["r"].to_i - 1
      rows[row_idx] ||= []
      row_node.xpath("c").each do |cell|
        ref = cell["r"]
        col_idx = cell_ref_to_col_index(ref)
        formula_node = cell.at_xpath("f")
        value_node = cell.at_xpath("v")
        inline_str = cell.at_xpath("is/t")

        if formula_node && formula_node.text.present?
          formulas[ref] = formula_node.text
          rows[row_idx][col_idx] = "=#{formula_node.text}"
        elsif cell["t"] == "inlineStr" && inline_str
          rows[row_idx][col_idx] = inline_str.text
        elsif cell["t"] == "s" && value_node
          rows[row_idx][col_idx] = shared_strings[value_node.text.to_i]
        elsif value_node
          rows[row_idx][col_idx] = value_node.text
        end
      end
    end

    merges = []
    doc.xpath("//mergeCell").each do |mc|
      merges << mc["ref"]
    end

    OpenStruct.new(
      rows: rows,
      formulas: formulas,
      merges: merges,
      shared_strings: shared_strings,
      column_count: rows.compact.map { |r| r&.size || 0 }.max || 0
    )
  end

  private

  def cell_ref_to_col_index(ref)
    col_str = ref.gsub(/\d+/, "")
    col_str.chars.reduce(0) { |sum, c| sum * 26 + (c.ord - "A".ord + 1) } - 1
  end
end
