require "open3"

class BackupRestoreRunner
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

    raise Error, "pg_restore lỗi:\n#{stderr}"
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

  def pg_env
    db = db_config
    env = { "LANG" => "C", "PGCLIENTENCODING" => "UTF8" }
    env["PGPASSWORD"] = db[:password] if db[:password]
    env
  end

  def db_config
    cfg = ActiveRecord::Base.connection_db_config.configuration_hash
    {
      dbname:   cfg[:database],
      host:     cfg[:host],
      port:     cfg[:port],
      user:     cfg[:username],
      password: cfg[:password]
    }
  end
end
