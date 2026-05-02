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

# ล้างข้อมูลเก่าทิ้งก่อน (เผื่อรันซ้ำนะ)
puts "🧹 กำลังล้างข้อมูลเก่า..."
UnlockedChapter.destroy_all
Purchase.destroy_all
Like.destroy_all
Follow.destroy_all
Chapter.destroy_all
Novel.destroy_all
User.destroy_all

puts "👤 สร้าง User จำลอง..."
admin = User.create!(
  username: "admin_neo",
  email: "admin@capstone.com",
  password: "password123",
  coin_balance: 1000000
)

author = User.create!(
  username: "writer_a",
  email: "writer@capstone.com",
  password: "password123",
  coin_balance: 0
)

reader = User.create!(
  username: "reader_bob",
  email: "reader@capstone.com",
  password: "password123",
  coin_balance: 500
)

puts "🎉 สร้างข้อมูลจำลอง เสร็จสมบูรณ์!"
puts "-------------------------------------------"
puts "📌 ข้อมูลสำหรับ Login ใน Postman:"
puts "คนอ่าน (เอาไว้เทสซื้อ)   -> Email: reader@capstone.com / Pass: password123"
puts "นักเขียน (เอาไว้รับ 60%) -> Email: writer@capstone.com / Pass: password123"
puts "เสี่ย (เอาไว้รับ 40%) -> Email: admin@capstone.com  / Pass: password123"
puts "-------------------------------------------"