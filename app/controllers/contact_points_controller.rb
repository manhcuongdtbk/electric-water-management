class ContactPointsController < ApplicationController
  include PeriodGuard
  include AuthorizeResource

  before_action :set_contact_point, only: [:show, :edit, :update, :destroy]
  before_action :require_open_period, only: [:create, :update, :destroy]

  TYPES = %w[residential public water_pump non_establishment].freeze

  def index
    @filter_type = params[:type] if TYPES.include?(params[:type])
    scope = load_collection(ContactPoint).includes(:unit, :zone, :block, :group, :meters)
    scope = scope.where(contact_point_type: @filter_type) if @filter_type
    if (q = params[:q]).present?
      scope = scope.where("contact_points.name ILIKE ?", "%#{q.strip}%")
    end
    scope = scope.order(:contact_point_type, :name)
    @total_count = scope.count
    @pagy, @contact_points = pagy(scope)
  end

  def show
  end

  def new
    @contact_point = ContactPoint.new(contact_point_type: params[:type] || "residential")
    @contact_point.meters.build if needs_meter?(@contact_point)
    authorize!(:create, @contact_point)
  end

  def create
    @contact_point = ContactPoint.new(create_params)
    @contact_point.initial_personnel_counts = personnel_counts_param
    authorize!(:create, @contact_point)

    if needs_meter?(@contact_point) && @contact_point.meters.empty?
      @contact_point.errors.add(:base,
        I18n.t("activerecord.errors.models.contact_point.attributes.base.must_have_at_least_one_meter"))
      @contact_point.meters.build
      render :new, status: :unprocessable_entity and return
    end

    if @contact_point.save
      redirect_to contact_points_path(type: @contact_point.contact_point_type),
                  notice: "Đã tạo đầu mối \"#{@contact_point.name}\"."
    else
      @contact_point.meters.build if @contact_point.meters.empty? && needs_meter?(@contact_point)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    ContactPoint.transaction do
      @contact_point.assign_attributes(update_params)

      if @contact_point.type_residential? && personnel_counts_param.present?
        update_personnel_entries_for_open_period(personnel_counts_param)
      end

      if @contact_point.save
        return redirect_to contact_points_path(type: @contact_point.contact_point_type),
                           notice: "Đã cập nhật đầu mối \"#{@contact_point.name}\"."
      else
        raise ActiveRecord::Rollback
      end
    end
    render :edit, status: :unprocessable_entity
  end

  def destroy
    if @contact_point.discard
      redirect_to contact_points_path(type: @contact_point.contact_point_type),
                  notice: "Đã xóa đầu mối \"#{@contact_point.name}\"."
    else
      redirect_to contact_points_path,
                  alert: @contact_point.errors.full_messages.join("\n")
    end
  end

  private

  def set_contact_point
    @contact_point = load_member(ContactPoint, action: action_auth_key)
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
    # T48: loại đầu mối immutable → không permit contact_point_type
    type = @contact_point.contact_point_type
    permitted = base_permitted_attributes(type) - [:contact_point_type]
    permitted += [meters_attributes: [:id, :name, :no_loss, :_destroy]]
    params.require(:contact_point).permit(*permitted)
  end

  def base_permitted_attributes(type)
    case type
    when "residential"
      [:name, :contact_point_type, :unit_id, :block_id, :group_id]
    when "public"
      [:name, :contact_point_type, :unit_id, :block_id, :group_id]
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

  def update_personnel_entries_for_open_period(counts)
    period = Period.current
    return unless period

    counts.each do |rank_id, count|
      entry = @contact_point.personnel_entries.find_by(period: period, rank_id: rank_id)
      next unless entry
      entry.update(count: count)
    end
  end
end
