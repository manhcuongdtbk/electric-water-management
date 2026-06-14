# Request-type shared example: SA sees the Khu vực/Đơn vị columns in the table
# header; non-SA accessible roles do not. Anti-vacuous precondition: SA's
# <thead> must actually contain every declared column, so a page without those
# columns fails instead of passing. Columns + users come from the scenario.
RSpec.shared_examples "role zone-unit column visibility" do
  it "zone/unit columns: SA thấy; non-SA không thấy" do
    sign_in scenario.sa_user
    get scenario.path
    sa_head = Nokogiri::HTML(response.body).css("thead").text
    scenario.columns.each do |col|
      expect(sa_head).to include(col)   # precondition: column really exists for SA
    end

    scenario.column_users.each do |user|
      sign_out :user
      sign_in user
      get scenario.path
      head = Nokogiri::HTML(response.body).css("thead").text
      scenario.columns.each do |col|
        expect(head).not_to include(col)
      end
    end
  end
end
