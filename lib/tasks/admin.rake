namespace :admin do
  desc "Create an admin user for testing"
  task create_admin: :environment do
    admin = User.find_or_initialize_by(email_address: "admin@example.com")
    admin.assign_attributes(
      password: "admin123456",
      password_confirmation: "admin123456",
      role: "admin",
      full_name: "Admin User"
    )
    
    if admin.save
      puts "Admin user created successfully!"
      puts "Email: admin@example.com"
      puts "Password: admin123456"
      puts "Role: admin"
    else
      puts "Failed to create admin user:"
      puts admin.errors.full_messages.join("\n")
    end
  end
  
  desc "Grant admin role to existing user"
  task :grant_admin, [:email] => :environment do |t, args|
    unless args[:email]
      puts "Please provide an email address: rake admin:grant_admin[user@example.com]"
      next
    end
    
    user = User.find_by(email_address: args[:email])
    if user
      user.update!(role: "admin")
      puts "Granted admin role to #{user.email_address}"
    else
      puts "User with email #{args[:email]} not found"
    end
  end
end