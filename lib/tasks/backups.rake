namespace :backups do
  desc 'Khôi phục cơ sở dữ liệu từ bản sao lưu. Sử dụng: bundle exec rails "backups:restore[backup_YYYYMMDD_HHMMSS.dump]"'
  task :restore, [:filename] => :environment do |_t, args|
    require "backup_restore_runner"

    if args[:filename].blank?
      abort 'Cần truyền tên file bản sao lưu. Ví dụ: bundle exec rails "backups:restore[backup_20250524_143000.dump]"'
    end

    backup = Backup.find_by!(filename: args[:filename])

    unless backup.file_exists?
      abort "Bản sao lưu \"#{backup.filename}\" không có file thực trên đĩa."
    end

    puts "----------------------------------------------------------"
    puts "CẢNH BÁO: Sắp khôi phục cơ sở dữ liệu từ bản sao lưu:"
    puts "  - File:       #{backup.filename}"
    puts "  - Kích thước: #{backup.human_size}"
    puts "  - Tạo lúc:    #{backup.created_at.in_time_zone('Asia/Ho_Chi_Minh')}"
    puts "  - Người tạo:  #{backup.created_by&.username || '(không xác định)'}"
    puts ""
    puts "Toàn bộ dữ liệu hiện tại sẽ bị GHI ĐÈ."
    puts "Gõ 'YES' (chính xác chữ hoa) để xác nhận, gõ khác để hủy:"
    print "> "

    confirmation = $stdin.gets.to_s.strip
    abort "Đã hủy." unless confirmation == "YES"

    BackupRestoreRunner.new(backup: backup).call
    puts "✓ Khôi phục hoàn tất từ \"#{backup.filename}\"."
  end
end
