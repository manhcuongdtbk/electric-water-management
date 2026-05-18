require "pagy/extras/overflow"
require "pagy/extras/i18n"

Pagy::DEFAULT[:limit]    = 25
Pagy::DEFAULT[:size]     = 7
Pagy::DEFAULT[:overflow] = :last_page

Pagy::I18n.load(locale: "vi", filepath: Rails.root.join("config/locales/pagy.vi.yml"))
