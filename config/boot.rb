# config/boot.rb
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup'

# ✅ ปิด bootsnap ถ้า memory ไม่พอ
BOOTSNAP_CACHE_DIR = ENV.fetch('BOOTSNAP_CACHE_DIR', 'tmp/cache')

if ENV['RAILS_ENV'] == 'development' && !ENV['DISABLE_BOOTSNAP']
  # ลองใช้ cache น้อยลง
  ENV['BOOTSNAP_CACHE_DIR'] = "#{BOOTSNAP_CACHE_DIR}/bootsnap"
  
  require 'bootsnap/setup'
  
  # ✅ ตั้งค่า memory limit
  Bootsnap.setup(
    cache_dir:            ENV['BOOTSNAP_CACHE_DIR'],
    development_mode:    true,
    load_path_cache:     true,
    compile_cache_iseq:  false,  # ปิด compile cache iseq
    compile_cache_yaml:  true
  )
end