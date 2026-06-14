# Generated per-role BEHAVIOR tests + completeness guardrail (#373, ADR-058).
# Sibling to role_access_matrix_spec.rb (#359, access). For every page in
# RoleBehaviorMatrix::BEHAVIORS and every dimension that `applies`, build the
# page's scenario and run the matching shared example (real assertions live
# there). The completeness block is added in a later task.
require "rails_helper"

RSpec.describe "Role behavior matrix (#373)", type: :request do
  SHARED_EXAMPLE_FOR = {
    data_scoping:         "role data scoping",
    zone_unit_columns:    "role zone-unit column visibility",
    commander_readonly:   "role commander read-only",
    zone_manager_variant: "role zone-manager variant"
  }.freeze

  RoleBehaviorMatrix::BEHAVIORS.each do |slug, dims|
    describe slug do
      dims.each do |dimension, entry|
        next unless entry.key?(:applies)

        describe dimension do
          let(:scenario) { RoleBehaviorScenarios.public_send(entry[:applies][:scenario]) }
          include_examples SHARED_EXAMPLE_FOR.fetch(dimension)
        end
      end
    end
  end
end
