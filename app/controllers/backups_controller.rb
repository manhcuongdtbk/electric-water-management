class BackupsController < ApplicationController
  def index
    # Authorization: chỉ technician truy cập (qua Ability — không grant cho role khác)
    raise CanCan::AccessDenied unless current_user.technician?
  end
end
