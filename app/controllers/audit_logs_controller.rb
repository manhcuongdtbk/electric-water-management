class AuditLogsController < ApplicationController
  AUDITED_MODELS = %w[
    User Zone Unit ContactPoint Meter MainMeter Block Group
    Period Rank PumpAllocation MeterReading MainMeterReading
    PersonnelEntry NonEstablishmentSnapshot UnitConfig OtherDeduction
    Backup
  ].freeze

  EVENTS = %w[create update destroy].freeze

  include ListSortable

  def index
    authorize!(:read, PaperTrail::Version)
    scope = PaperTrail::Version.all
    scope = apply_filters(scope)
    scope = scope.order(created_at: :desc)
    @total_count = scope.count
    @pagy, @versions = pagy_with_per_page(scope)
    @audited_models = AUDITED_MODELS
    @events = EVENTS
    @users = User.order(:username).pluck(:username, :id)
    # Preload usernames cho whodunnit ID → tránh N+1 trong view (mỗi row 1 query).
    whodunnit_ids = @versions.map(&:whodunnit).compact.uniq
    @whodunnit_by_id = User.where(id: whodunnit_ids).pluck(:id, :username).to_h
  end

  def show
    authorize!(:read, PaperTrail::Version)
    @version = PaperTrail::Version.find(params[:id])
    @before_object = decode_yaml(@version.object)
    @changes = decode_yaml(@version.object_changes)
    @whodunnit_by_id = { @version.whodunnit.to_i => User.find_by(id: @version.whodunnit)&.username }.compact
  end

  private

  def apply_filters(scope)
    if (event = params[:event]).present? && EVENTS.include?(event)
      scope = scope.where(event: event)
    end

    if (item_type = params[:item_type]).present? && AUDITED_MODELS.include?(item_type)
      scope = scope.where(item_type: item_type)
    end

    if (whodunnit = params[:whodunnit]).present?
      scope = scope.where(whodunnit: whodunnit.to_s)
    end

    if (from = parse_date(params[:from]))
      scope = scope.where("versions.created_at >= ?", from.beginning_of_day)
    end

    if (to = parse_date(params[:to]))
      scope = scope.where("versions.created_at <= ?", to.end_of_day)
    end

    scope
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  def decode_yaml(yaml_str)
    return nil if yaml_str.blank?
    YAML.unsafe_load(yaml_str)
  rescue Psych::Exception, ArgumentError, TypeError
    nil
  end
end
