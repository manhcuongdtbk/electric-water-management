class AuditLogsController < ApplicationController
  def index
    authorize!(:read, PaperTrail::Version)
    @versions = PaperTrail::Version.order(created_at: :desc).limit(50)
  end
end
