require "rails_helper"

RSpec.describe BillingHelper, type: :helper do
  describe "#compute_rowspans" do
    it "delegate tới Billing::RowspanComputer" do
      calcs = []
      result = helper.compute_rowspans(calcs, show_zone: true, show_unit: true)
      expect(result).to eq([])
    end
  end

  describe "#billing_column_signature" do
    it "sinh signature khác nhau theo flag" do
      expect(helper.billing_column_signature(show_zone: true, show_unit: true)).to eq("z1-u1")
      expect(helper.billing_column_signature(show_zone: false, show_unit: false)).to eq("z0-u0")
    end
  end
end
