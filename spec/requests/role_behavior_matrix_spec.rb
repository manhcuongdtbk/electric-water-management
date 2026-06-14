# Generated per-role BEHAVIOR tests + completeness guardrail (#373, ADR-058).
# Sibling to role_access_matrix_spec.rb (#359, access). For every page in
# RoleBehaviorMatrix::BEHAVIORS and every dimension that `applies`, build the
# page's scenario and run the matching shared example (real assertions live
# there). The completeness block below forces every access-matrix page to
# declare all 4 dimensions (applies + scenario, or na + reason).
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

  describe "completeness (guardrail #373)" do
    it "mọi trang access-matrix đều khai hành vi (không thiếu, không stale)" do
      gaps = RoleBehaviorMatrix.coverage_gaps
      expect(gaps[:missing]).to be_empty,
        "Trang access-matrix chưa khai hành vi: #{gaps[:missing].join(', ')}. " \
        "Thêm vào RoleBehaviorMatrix::BEHAVIORS (mỗi dimension applies hoặc na kèm lý do)."
      expect(gaps[:stale]).to be_empty,
        "Entry BEHAVIORS không có trang access tương ứng: #{gaps[:stale].join(', ')}."
    end

    it "mỗi trang khai đủ 4 dimension hành vi" do
      gaps = RoleBehaviorMatrix.dimension_gaps
      expect(gaps).to be_empty,
        "Trang thiếu dimension: #{gaps.map { |s, d| "#{s} (#{d.join(', ')})" }.join('; ')}."
    end

    it "mọi entry đúng hình thức (na có lý do, applies có scenario)" do
      bad = RoleBehaviorMatrix.invalid_entries
      expect(bad).to be_empty,
        "Entry sai hình thức: #{bad.map { |s, d| "#{s} (#{d.join(', ')})" }.join('; ')}."
    end
  end
end
