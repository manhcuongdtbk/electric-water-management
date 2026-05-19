class BackupsController < ApplicationController
  before_action :authorize_backup_management

  def index
    @backups = Backup.recent.includes(:created_by).to_a
    @at_capacity = Backup.at_capacity?
    @max_count = Backup::MAX_COUNT
    @total_size_bytes = @backups.sum(&:size_bytes)
  end

  def create
    result = BackupService.create(user: current_user)
    redirect_to backups_path,
      notice: I18n.t("backups.flash.created", filename: result.backup.filename)
  rescue BackupService::CapacityError, BackupService::DumpError => e
    redirect_to backups_path, alert: e.message
  end

  def destroy
    backup = Backup.find(params[:id])
    authorize!(:destroy, backup)
    delete_file_if_exists(backup)
    backup.destroy!
    redirect_to backups_path,
      notice: I18n.t("backups.flash.destroyed", filename: backup.filename)
  end

  private

  def authorize_backup_management
    authorize!(:manage, Backup)
  end

  def delete_file_if_exists(backup)
    path = backup.absolute_path
    File.delete(path) if path.exist?
  end
end
