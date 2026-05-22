require "rails_helper"

RSpec.describe ListHelper, type: :helper do
  describe "#sortable_header" do
    let(:base_params) { { q: "test", per_page: "25" } }

    before do
      allow(helper).to receive(:url_for) do |params|
        "/test?" + params.to_query
      end
    end

    def render_header(sort: nil, dir: nil)
      helper.sortable_header(:zone, "Khu vực",
        current_sort: sort, current_dir: dir,
        extra_params: base_params)
    end

    it "hiển thị ⇅ khi chưa sort cột này" do
      result = render_header
      expect(result).to include("⇅")
    end

    it "hiển thị ↑ khi sort ASC" do
      result = render_header(sort: "zone", dir: "asc")
      expect(result).to include("↑")
      expect(result).not_to include("⇅")
    end

    it "hiển thị ↓ khi sort DESC" do
      result = render_header(sort: "zone", dir: "desc")
      expect(result).to include("↓")
      expect(result).not_to include("⇅")
    end

    it "chưa sort → link chứa sort ASC" do
      result = render_header
      expect(result).to include("sort=zone")
      expect(result).to include("dir=asc")
    end

    it "sort ASC → link chứa sort DESC" do
      result = render_header(sort: "zone", dir: "asc")
      expect(result).to include("sort=zone")
      expect(result).to include("dir=desc")
    end

    it "sort DESC → link xóa sort (không chứa sort= và dir=)" do
      result = render_header(sort: "zone", dir: "desc")
      expect(result).not_to include("sort=")
      expect(result).not_to include("dir=")
    end

    it "giữ lại extra_params trong link" do
      result = render_header
      expect(result).to include("q=test")
      expect(result).to include("per_page=25")
    end

    it "cột khác không bị ảnh hưởng khi sort cột này" do
      result = helper.sortable_header(:target, "Đối tượng",
        current_sort: "zone", current_dir: "asc",
        extra_params: base_params)
      expect(result).to include("⇅")
      expect(result).to include("sort=target")
      expect(result).to include("dir=asc")
    end
  end
end
