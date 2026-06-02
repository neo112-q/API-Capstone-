require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AuthApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # ✅ ตั้งค่า timezone ให้เป็น Bangkok (ประเทศไทย)
    config.time_zone = 'Asia/Bangkok'
    
    # ✅ เก็บ datetime ใน Database เป็น UTC (ค่าเริ่มต้นของ Rails)
    # ไม่ต้องแก้ตรงนี้เพราะ default เป็น UTC อยู่แล้ว
    # config.active_record.default_timezone = :utc  # ← ค่า default อยู่แล้ว
    
    # ✅ เพิ่ม middleware สำหรับ session และ cookies (จำเป็นสำหรับ authentication บางอย่าง)
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore
    
    # ✅ ตั้งค่า API mode แต่ยังให้รองรับ session ได้
    config.api_only = false  # เปลี่ยนเป็น false เพื่อให้ใช้ session ได้
    
    # ✅ กำหนด allowed hosts (ป้องกัน DNS rebinding attacks)
    # config.hosts << "yourdomain.com"  # เพิ่มเมื่อ deploy จริง
    
    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    # config.api_only = true  # comment out หรือเปลี่ยนเป็น false
  end
end