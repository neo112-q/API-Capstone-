namespace :admin do
  desc "Ensure admin user exists (non-destructive)"
  task ensure: :environment do
    if User.exists?(username: "admin")
      puts "Admin user already exists."
    else
      admin = User.create!(
        username: "admin",
        email: "admin@novelhub.com",
        password: "admin123",
        password_confirmation: "admin123",
        coin_balance: 1_000_000,
        role: "admin",
        status: "active"
      )
      puts "Admin user created successfully!"
      puts "  Email:    admin@novelhub.com"
      puts "  Password: admin123"
    end
  end
end
