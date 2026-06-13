require "rails_helper"

RSpec.describe "Demo recording smoke", type: :demo do
  it "shows a caption banner on each step" do
    demo = DemoRecorder.new(self)
    demo.visit("/", caption: "Mở trang đăng nhập")
    expect(page).to have_css("#demo-caption", text: "Mở trang đăng nhập")
  end
end
