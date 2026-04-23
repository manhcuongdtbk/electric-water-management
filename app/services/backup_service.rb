require "open3"

class BackupService
  BACKUP_DIR = ENV.fetch("BACKUP_DIR", Rails.root.join("db/backups").to_s)

  def self.backup!
    FileUtils.mkdir_p(BACKUP_DIR)
    filename = "backup_#{Time.current.strftime('%Y%m%d_%H%M%S')}.dump"
    filepath = File.join(BACKUP_DIR, filename)
    cfg = db_config
    env = { "PGPASSWORD" => cfg[:password].to_s }
    cmd = [ "pg_dump", "-h", cfg[:host], "-p", cfg[:port].to_s,
            "-U", cfg[:username], "-Fc", "-f", filepath, cfg[:database] ]
    _stdout, stderr, status = Open3.capture3(env, *cmd)
    unless status.success?
      Rails.logger.error("pg_dump failed: #{stderr}")
      raise "pg_dump failed: #{stderr.truncate(200)}"
    end
    filename
  end

  def self.restore!(filename)
    filepath = safe_filepath!(filename)
    cfg = db_config
    env = { "PGPASSWORD" => cfg[:password].to_s }
    cmd = [ "pg_restore", "-h", cfg[:host], "-p", cfg[:port].to_s,
            "-U", cfg[:username], "-d", cfg[:database],
            "--clean", "--no-owner", "--no-acl", "-1", filepath ]
    _stdout, stderr, status = Open3.capture3(env, *cmd)
    unless status.success?
      Rails.logger.error("pg_restore failed: #{stderr}")
      raise "pg_restore failed: #{stderr.truncate(200)}"
    end
  end

  def self.list
    Dir.glob(File.join(BACKUP_DIR, "*.dump"))
       .map { |f| { name: File.basename(f), size: File.size(f), created_at: File.mtime(f) } }
       .sort_by { |f| f[:created_at] }.reverse
  end

  def self.delete!(filename)
    File.delete(safe_filepath!(filename))
  end

  def self.db_config
    cfg = ActiveRecord::Base.connection_db_config.configuration_hash
    {
      host: cfg[:host] || "localhost",
      port: cfg[:port] || 5432,
      username: cfg[:username],
      password: cfg[:password],
      database: cfg[:database]
    }
  end
  private_class_method :db_config

  def self.safe_filepath!(filename)
    raise ArgumentError, "invalid filename" if filename.include?("/") || filename.include?("..")
    filepath = File.join(BACKUP_DIR, filename)
    raise "File not found" unless File.exist?(filepath)
    filepath
  end
  private_class_method :safe_filepath!
end
