require "open3"

class BackupRestoreRunner
  include DatabaseConfig

  Error = Class.new(StandardError)

  def initialize(backup:)
    @backup = backup
  end

  def call
    raise Error, I18n.t("backups.errors.file_missing") unless @backup.file_exists?

    ActiveRecord::Base.connection_pool.disconnect!

    cmd = pg_restore_command
    env = pg_env
    _stdout, stderr, status = Open3.capture3(env, *cmd)

    return if status.success?

    raise Error, I18n.t("backups.errors.pg_restore_failed", message: stderr.to_s)
  ensure
    ActiveRecord::Base.establish_connection
  end

  private

  def pg_restore_command
    db = db_config
    cmd = [
      "pg_restore",
      "--clean",
      "--if-exists",
      "--no-owner",
      "--no-privileges",
      "--dbname=#{db[:dbname]}"
    ]
    cmd << "--host=#{db[:host]}" if db[:host]
    cmd << "--port=#{db[:port]}" if db[:port]
    cmd << "--username=#{db[:user]}" if db[:user]
    cmd << @backup.absolute_path.to_s
    cmd
  end
end
