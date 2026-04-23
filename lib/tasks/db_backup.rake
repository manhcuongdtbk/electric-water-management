namespace :db do
  desc "Backup database to BACKUP_DIR (default: db/backups/)"
  task backup: :environment do
    filename = BackupService.backup!
    puts "Backup created: #{filename}"
  end

  desc "Restore database from backup file. Usage: rails 'db:restore[filename.dump]'"
  task :restore, [ :filename ] => :environment do |_, args|
    raise "Usage: rails 'db:restore[filename.dump]'" if args[:filename].blank?
    BackupService.restore!(args[:filename])
    puts "Restore complete: #{args[:filename]}"
  end
end
