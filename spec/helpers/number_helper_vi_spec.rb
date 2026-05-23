require "rails_helper"

RSpec.describe NumberHelperVi, type: :helper do
  describe "#number_to_vi" do
    it "format 2 chữ số thập phân, dấu chấm nghìn, dấu phẩy thập phân" do
      expect(helper.number_to_vi(96578.38)).to eq("96.578,38")
    end

    it "ROUND_HALF_UP — 5 làm tròn lên" do
      expect(helper.number_to_vi(1.235)).to eq("1,24")
      expect(helper.number_to_vi(1.245)).to eq("1,25")
    end

    it "precision tùy chỉnh" do
      expect(helper.number_to_vi(1234.5678, precision: 0)).to eq("1.235")
      expect(helper.number_to_vi(1234.5678, precision: 3)).to eq("1.234,568")
    end

    it "nil → chuỗi rỗng" do
      expect(helper.number_to_vi(nil)).to eq("")
    end

    it "0 → 0,00 (giữ đúng 2 chữ số thập phân)" do
      expect(helper.number_to_vi(0)).to eq("0,00")
    end

    it "số âm — giữ đúng precision" do
      expect(helper.number_to_vi(-1234.5)).to eq("-1.234,50")
    end
  end

  describe "#unit_price_to_vi" do
    it "hiển thị đầy đủ thập phân, không làm tròn" do
      expect(helper.unit_price_to_vi(2336.4)).to eq("2.336,4")
    end

    it "số nguyên không có phần thập phân" do
      expect(helper.unit_price_to_vi(2336)).to eq("2.336")
    end

    it "nhiều chữ số thập phân giữ nguyên" do
      expect(helper.unit_price_to_vi(2336.456)).to eq("2.336,456")
    end

    it "nil → chuỗi rỗng" do
      expect(helper.unit_price_to_vi(nil)).to eq("")
    end
  end

  describe "#money_to_vi" do
    it "0 chữ số thập phân, dấu chấm nghìn, thêm đ" do
      expect(helper.money_to_vi(96578.38)).to eq("96.578 đ")
    end

    it "ROUND_HALF_UP — 0.5 làm tròn lên" do
      expect(helper.money_to_vi(100.5)).to eq("101 đ")
    end

    it "nil → chuỗi rỗng" do
      expect(helper.money_to_vi(nil)).to eq("")
    end
  end

  describe "#money_to_vi_plain" do
    it "không có đ ở cuối" do
      expect(helper.money_to_vi_plain(96578.38)).to eq("96.578")
    end

    it "nil → chuỗi rỗng" do
      expect(helper.money_to_vi_plain(nil)).to eq("")
    end
  end
end
