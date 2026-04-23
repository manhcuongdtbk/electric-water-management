class BackupsController < ApplicationController
  before_action :authorize_backup

  def index
    @backups = BackupService.list
  end

  def create
    filename = BackupService.backup!
    redirect_to backups_path, notice: t("flash.backups.created", filename: filename)
  rescue => e
    redirect_to backups_path, alert: t("flash.backups.create_failed", error: e.message)
  end

  def restore
    BackupService.restore!(params.require(:filename))
    sign_out current_user
    redirect_to new_user_session_path, notice: t("flash.backups.restored")
  rescue => e
    redirect_to backups_path, alert: t("flash.backups.restore_failed", error: e.message)
  end

  def destroy_file
    BackupService.delete!(params.require(:filename))
    redirect_to backups_path, notice: t("flash.backups.deleted")
  rescue => e
    redirect_to backups_path, alert: t("flash.backups.delete_failed", error: e.message)
  end

  private

  def authorize_backup
    authorize! :manage, :backup
  end
end
