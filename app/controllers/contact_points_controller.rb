class ContactPointsController < ApplicationController
  include PeriodGuard
  include StructureChangeGuard
  include AuthorizeResource
  include BusinessRoleRequired
  include ZoneUnitFilterable

  before_action :set_contact_point, only: [:show, :edit, :update, :destroy]
  before_action :set_available_zones, only: [:new, :edit, :create, :update]
  before_action :require_open_period, only: [:create, :update, :destroy]
  before_action :require_latest_period_when_open,
    only: [:new, :create, :destroy]

  TYPES = %w[residential public water_pump non_establishment].freeze

  SORT_COLUMNS = {
    name:               "contact_points.name",
    contact_point_type: "contact_points.contact_point_type",
    zone:               "COALESCE(zones.name, unit_zones.name)",
    unit:               "units.name",
    block:              "blocks.name",
    group:              "groups.name",
    created_at:         "contact_points.created_at"
  }.freeze

  def index
    @period = current_period
    scope = load_collection(ContactPoint)
              .includes(:zone, :block, :group, unit: :zone)
              .left_joins(:unit, :zone, :block, :group)
              .joins("LEFT JOIN zones unit_zones ON unit_zones.id = units.zone_id")

    @filter_type = params[:type] if TYPES.include?(params[:type])
    scope = scope.where(contact_point_type: @filter_type) if @filter_type

    scope = apply_sa_zone_unit_filter_with_direct_zone(scope)

    @visible_types = %w[residential public]
    @visible_types += %w[water_pump non_establishment] if current_user.system_admin? || current_zone_manager?

    scope = apply_search(scope, columns: "contact_points.name")
    scope = apply_sort(scope, allowed: SORT_COLUMNS, default: [:created_at, :desc])
    @total_count = scope.count
    @pagy, @contact_points = pagy_with_per_page(scope)
  end

  def show
  end

  def new
    requested_type = params[:type] || "residential"
    if current_user.unit_id.present? && !current_zone_manager? && %w[water_pump non_establishment].include?(requested_type)
      requested_type = "residential"
    end
    @contact_point = ContactPoint.new(contact_point_type: requested_type)
    @contact_point.unit_id = current_user.unit_id if current_user.unit_id.present?
    @contact_point.meters.build if needs_meter?(@contact_point)
    authorize!(:create, @contact_point)
  end

  def create
    @contact_point = ContactPoint.new(create_params)
    @contact_point.initial_personnel_counts = personnel_counts_param
    if @contact_point.zone_id.present?
      @contact_point.unit_id = nil
      @contact_point.block_id = nil
      @contact_point.group_id = nil
    elsif current_user.unit_id.present?
      @contact_point.unit_id = current_user.unit_id
    end
    authorize!(:create, @contact_point)

    if needs_meter?(@contact_point) && @contact_point.meters.empty?
      @contact_point.errors.add(:base,
        I18n.t("activerecord.errors.models.contact_point.attributes.base.must_have_at_least_one_meter"))
      @contact_point.meters.build
      render :new, status: :unprocessable_entity and return
    end

    if @contact_point.save
      redirect_to contact_points_path(type: @contact_point.contact_point_type),
                  notice: t("flash.record_created", resource: t("resources.contact_point"), name: @contact_point.name)
    else
      @contact_point.meters.build if @contact_point.meters.empty? && needs_meter?(@contact_point)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    ContactPoint.transaction do
      meter_ids_to_discard = extract_meters_to_discard
      @contact_point.assign_attributes(update_params)

      if @contact_point.type_residential? && personnel_counts_param.present?
        update_personnel_entries_for_open_period(personnel_counts_param, personnel_lock_versions_param)
      end

      if @contact_point.type_non_establishment? && reopened_old_period?
        update_non_establishment_snapshot_for_open_period
      end

      validate_minimum_meters(meter_ids_to_discard)

      if @contact_point.errors.any? || !@contact_point.save
        raise ActiveRecord::Rollback
      end

      discard_meters!(meter_ids_to_discard)

      return redirect_to contact_points_path(type: @contact_point.contact_point_type),
                         notice: t("flash.record_updated", resource: t("resources.contact_point"), name: @contact_point.name)
    end
    @contact_point.meters.build if @contact_point.meters.kept.empty? && needs_meter?(@contact_point)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    if @contact_point.discard
      redirect_to contact_points_path(type: @contact_point.contact_point_type),
                  notice: t("flash.record_destroyed", resource: t("resources.contact_point"), name: @contact_point.name)
    else
      redirect_to contact_points_path,
                  alert: @contact_point.errors.full_messages.join("\n")
    end
  end

  private

  def set_contact_point
    @contact_point = load_member(ContactPoint, action: action_auth_key)
  end

  def set_available_zones
    @available_zones = if current_user.system_admin?
      Zone.kept
    else
      Zone.kept.where(id: current_user.unit&.zone_id)
    end
  end

  def action_auth_key
    case action_name
    when "show" then :read
    when "edit", "update" then :update
    when "destroy" then :destroy
    end
  end

  def needs_meter?(cp)
    cp.type_residential? || cp.type_public? || cp.type_water_pump?
  end

  def create_params
    type = params.dig(:contact_point, :contact_point_type)
    permitted = base_permitted_attributes(type)
    permitted += [meters_attributes: [:name, :no_loss, :_destroy]]
    params.require(:contact_point).permit(*permitted)
  end

  def update_params
    # T48: loại đầu mối, nơi thuộc về (unit/zone) immutable sau khi tạo.
    # Không permit contact_point_type, unit_id, zone_id.
    if reopened_old_period?
      # Kỳ cũ mở lại: chỉ cho sửa data per kỳ, không cho sửa cấu trúc.
      #
      # Residential: quân số qua personnel_counts_param → update_personnel_entries_for_open_period
      #              (không đi qua update_params). no_loss qua meters_attributes.
      # Public/Water_pump: no_loss qua meters_attributes.
      # Non_establishment: quân số qua update_non_establishment_snapshot_for_open_period
      #   (sửa snapshot trực tiếp, không đụng master contact_point.personnel_count
      #    vì sửa master khi kỳ cũ sẽ ghi đè giá trị hiện tại).
      params.require(:contact_point).permit(
        meters_attributes: [:id, :no_loss]
      )
    else
      type = @contact_point.contact_point_type
      permitted = base_permitted_attributes(type) - [:contact_point_type, :unit_id, :zone_id]
      permitted += [meters_attributes: [:id, :name, :no_loss, :_destroy]]
      params.require(:contact_point).permit(*permitted)
    end
  end


  def base_permitted_attributes(type)
    case type
    when "residential"
      [:name, :contact_point_type, :unit_id, :zone_id, :block_id, :group_id]
    when "public"
      [:name, :contact_point_type, :unit_id, :zone_id]
    when "water_pump"
      [:name, :contact_point_type, :zone_id]
    when "non_establishment"
      [:name, :contact_point_type, :zone_id, :personnel_count]
    else
      [:name, :contact_point_type, :unit_id, :zone_id, :block_id, :group_id, :personnel_count]
    end
  end

  def personnel_counts_param
    raw = params.dig(:contact_point, :personnel_counts)
    return {} if raw.blank?
    hash = raw.is_a?(ActionController::Parameters) ? raw.to_unsafe_h : raw.to_h
    hash.transform_keys(&:to_i).transform_values(&:to_i)
  end

  def personnel_lock_versions_param
    raw = params.dig(:contact_point, :personnel_lock_versions)
    return {} if raw.blank?
    hash = raw.is_a?(ActionController::Parameters) ? raw.to_unsafe_h : raw.to_h
    hash.transform_keys(&:to_i).transform_values(&:to_i)
  end

  def extract_meters_to_discard
    raw = params.dig(:contact_point, :meters_attributes)
    return [] unless raw

    ids = []
    raw.each do |key, attrs|
      if attrs[:_destroy] == "1" && attrs[:id].present?
        ids << attrs[:id].to_i
        raw.delete(key)
      end
    end
    ids
  end

  def validate_minimum_meters(meter_ids_to_discard)
    return if meter_ids_to_discard.empty?
    return unless needs_meter?(@contact_point)

    remaining = @contact_point.meters.kept.where.not(id: meter_ids_to_discard).count +
                @contact_point.meters.select(&:new_record?).size
    if remaining < 1
      @contact_point.errors.add(:base,
        I18n.t("activerecord.errors.models.contact_point.attributes.base.must_have_at_least_one_meter"))
    end
  end

  def discard_meters!(meter_ids)
    return if meter_ids.empty?
    @contact_point.meters.kept.where(id: meter_ids).find_each(&:discard)
  end

  def update_personnel_entries_for_open_period(counts, lock_versions)
    period = Period.current
    return unless period

    counts.each do |rank_id, count|
      entry = @contact_point.personnel_entries.find_by(period: period, rank_id: rank_id)
      next unless entry
      attrs = { count: count }
      # Optimistic locking: nếu form gửi lock_version → gán vào entry để Rails compare
      # với giá trị trong DB. Mismatch → StaleObjectError (catch ở OptimisticLockingGuard).
      attrs[:lock_version] = lock_versions[rank_id] if lock_versions.key?(rank_id)
      entry.update(attrs)
    end
  end

  # Kỳ cũ mở lại: sửa non_establishment_snapshots.personnel_count trực tiếp,
  # không qua contact_point.personnel_count (master). Sửa master khi kỳ cũ sẽ ghi đè
  # giá trị hiện tại → form kỳ mới nhất hiện sai → nguy cơ cascade sai data.
  def update_non_establishment_snapshot_for_open_period
    period = Period.current
    return unless period
    new_count = params.dig(:contact_point, :personnel_count)
    return if new_count.blank?
    snapshot = @contact_point.non_establishment_snapshots.find_by(period: period)
    snapshot&.update!(personnel_count: new_count.to_i)
  end
end
