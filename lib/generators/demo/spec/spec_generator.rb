require "rails/generators"

module Demo
  # Scaffold for a demo spec (ADR-051): `rails g demo:spec <feature>` emits an
  # EMPTY but runnable skeleton under spec/demo/ — DemoRecorder boilerplate, the
  # "demo seeded world" context, caption TODOs and an NV-... anchor placeholder.
  # It deliberately does NOT read acceptance criteria or pre-fill the journey:
  # the author (with an AI assistant) writes the journey + Vietnamese captions,
  # and a human reviews the produced video (ADR-050). See
  # docs/superpowers/specs/2026-06-14-ai-soan-demo-scaffold-design.md.
  #
  # NOTE: lib/generators is excluded from zeitwerk autoloading via
  # config.autoload_lib(ignore: [..., "generators"]) in config/application.rb,
  # so this constant is loaded by the Rails generators lookup, not zeitwerk.
  class SpecGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    desc "Create an empty, runnable demo spec skeleton under spec/demo/."

    def create_demo_spec
      template "demo_spec.rb.tt", File.join("spec/demo", "#{file_name}_demo_spec.rb")
    end
  end
end
