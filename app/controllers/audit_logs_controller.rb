class AuditLogsController < ApplicationController
  include Pagy::Method

  def index
    authorize! :read, :audit_log

    versions = PaperTrail::Version.order(created_at: :desc)
    versions = versions.where(whodunnit: params[:whodunnit]) if params[:whodunnit].present?
    versions = versions.where(item_type: params[:item_type]) if params[:item_type].present?
    if params[:date_from].present?
      versions = versions.where("created_at >= ?", params[:date_from].to_date.beginning_of_day)
    end
    if params[:date_to].present?
      versions = versions.where("created_at <= ?", params[:date_to].to_date.end_of_day)
    end

    @pagy, @versions = pagy(versions, limit: 25)

    whodunnit_ids = @versions.map(&:whodunnit).compact.uniq
    @users_map = User.where(id: whodunnit_ids).index_by { |u| u.id.to_s }
    @all_users = User.order(:full_name)
    @item_types = PaperTrail::Version.distinct.pluck(:item_type).sort
  end
end
