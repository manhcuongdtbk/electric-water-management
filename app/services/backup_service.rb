require "open3"
require "fileutils"

class BackupService
  include DatabaseConfig

  Error = Class.new(StandardError)
  CapacityError = Class.new(Error)
  DumpError = Class.new(Error)

  Result = Struct.new(:backup, :warnings, keyword_init: true)

  def self.backup_dir
    path = ENV["BACKUP_DIR"].presence || Rails.root.join("storage/backups").to_s
    Pathname.new(path)
  end

  def self.create(user:)
    new(user: user).create
  end

  def initialize(user:)
    @user = user
  end

  def create
    if Backup.at_capacity?
      raise CapacityError, I18n.t("backups.errors.at_capacity", max: Backup::MAX_COUNT)
    end

    ensure_directory_exists
    filename = build_filename
    absolute_path = self.class.backup_dir.join(filename)

    begin
      run_pg_dump!(absolute_path)
      size = File.size(absolute_path)
      backup = Backup.create!(
        filename: filename,
        size_bytes: size,
        status: "completed",
        created_by: @user
      )
      Result.new(backup: backup, warnings: [])
    rescue StandardError
      # Cleanup file orphan nếu pg_dump fail HOẶC Backup record save fail
      # (vd filename collision hiếm gặp).
      File.delete(absolute_path) if absolute_path.exist?
      raise
    end
  end

  private

  def build_filename
    timestamp = Time.current.in_time_zone("Asia/Ho_Chi_Minh").strftime("%Y%m%d_%H%M%S")
    "backup_#{timestamp}.dump"
  end

  def ensure_directory_exists
    FileUtils.mkdir_p(self.class.backup_dir)
  end

  def run_pg_dump!(absolute_path)
    cmd = pg_dump_command(absolute_path)
    env = pg_env
    _stdout, stderr, status = Open3.capture3(env, *cmd)
    return if status.success?

    message = stderr.to_s.lines.first.to_s.strip
    raise DumpError, I18n.t("backups.errors.pg_dump_failed", message: message)
  end

  def pg_dump_command(absolute_path)
    db = db_config
    cmd = [
      "pg_dump",
      "--format=custom",
      "--no-owner",
      "--no-privileges",
      "--file=#{absolute_path}",
      "--dbname=#{db[:dbname]}"
    ]
    cmd << "--host=#{db[:host]}" if db[:host]
    cmd << "--port=#{db[:port]}" if db[:port]
    cmd << "--username=#{db[:user]}" if db[:user]
    cmd
  end
end
