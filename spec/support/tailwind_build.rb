RSpec.configure do |config|
  config.before(:suite) do
    tailwind_css = Rails.root.join("app/assets/builds/tailwind.css")
    unless tailwind_css.exist?
      system("bin/rails tailwindcss:build", out: File::NULL, err: File::NULL) ||
        abort("tailwindcss:build failed — run: bin/rails tailwindcss:build")
    end
  end
end
