namespace :admin do
  desc "Reset password and unlock account — escape hatch for last-admin lockout scenarios"
  task :reset_password, [ :email ] => :environment do |_t, args|
    email = args[:email]
    abort "Usage: rails admin:reset_password[email@example.com]" if email.blank?

    user = User.find_by(email: email)
    abort "User not found: #{email}" if user.nil?

    new_password = SecureRandom.alphanumeric(12)
    user.password              = new_password
    user.password_confirmation = new_password
    user.locked_at             = nil
    user.failed_attempts       = 0
    user.force_password_change = true
    user.save!(validate: false)

    puts "=" * 60
    puts "Password reset for #{email}"
    puts "New password: #{new_password}"
    puts "locked_at: nil (unlocked)"
    puts "failed_attempts: 0"
    puts "force_password_change: true"
    puts "=" * 60
  end
end
