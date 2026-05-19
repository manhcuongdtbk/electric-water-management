module DatabaseConfig
  # Build env hash cho lệnh pg_* (pg_dump, pg_restore, psql).
  # Set PGPASSWORD qua env thay vì argv để tránh password leak trong process list.
  # LANG=C tránh warning locale, PGCLIENTENCODING=UTF8 đảm bảo encoding.
  def pg_env
    db = db_config
    env = { "LANG" => "C", "PGCLIENTENCODING" => "UTF8" }
    env["PGPASSWORD"] = db[:password] if db[:password]
    env
  end

  # Đọc connection config từ ActiveRecord (hỗ trợ cả database.yml và DATABASE_URL).
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
