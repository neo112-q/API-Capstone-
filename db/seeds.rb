# db/seeds.rb

genres_list = [
  "romance", "comedy", "girl love", "boy love", "fantasy", 
  "science", "fiction", "mystery", "war", "adventure", 
  "action", "thriller", "horror"
]

puts "กำลังเพิ่มหมวดหมู่นิยายลง Database..."

genres_list.each do |genre_name|
  Genre.find_or_create_by!(name: genre_name)
end

puts "เพิ่มหมวดหมู่สำเร็จ! มีทั้งหมด #{Genre.count} หมวดหมู่"

puts "กำลังล้างข้อมูลเก่า..."

begin
  # ลบข้อมูลที่มี foreign key ก่อน
  ActiveRecord::Base.connection.execute("DELETE FROM unlocked_chapters")
  ActiveRecord::Base.connection.execute("DELETE FROM purchases")
  ActiveRecord::Base.connection.execute("DELETE FROM chapter_likes")
  ActiveRecord::Base.connection.execute("DELETE FROM chapter_views")
  ActiveRecord::Base.connection.execute("DELETE FROM follows")
  ActiveRecord::Base.connection.execute("DELETE FROM reading_histories")
  ActiveRecord::Base.connection.execute("DELETE FROM novel_genres")
  
  # ลบ chapters ก่อน novels
  ActiveRecord::Base.connection.execute("DELETE FROM chapters")
  
  # สุดท้ายค่อยลบ novels และ users
  ActiveRecord::Base.connection.execute("DELETE FROM novels")
  ActiveRecord::Base.connection.execute("DELETE FROM users")
  
  # reset sequence ให้ id เริ่มที่ 1 ใหม่
  ActiveRecord::Base.connection.execute("ALTER SEQUENCE users_id_seq RESTART WITH 1")
  ActiveRecord::Base.connection.execute("ALTER SEQUENCE novels_id_seq RESTART WITH 1")
  
rescue => e
  puts "error: #{e.message}"
end

puts "สร้าง Admin สำหรับดูแลระบบ"

admin = User.create!(
  username: "admin",
  email: "admin@novelhub.com",
  password: "admin123",
  password_confirmation: "admin123",
  coin_balance: 1_000_000,
  role: "admin",
  status: "active"
)

puts "สร้างข้อมูลจำลอง เสร็จสมบูรณ์!"
puts "-------------------------------------------"
puts "   ข้อมูลสำหรับ Login:Admin"
puts "   ADMIN:"
puts "   Email: admin@novelhub.com"
puts "   Password: admin123"
puts "-------------------------------------------"