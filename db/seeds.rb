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

puts "📚 สร้างนิยายจำลอง..."
novel_1 = Novel.create!(
  user: author,
  title: "เกิดใหม่ทั้งที ขอเป็นเศรษฐีละกัน!",
  pen_name: "อาจารย์ A",
  description: "นิยายแนวแฟนตาซีทะลุมิติ...",
  status: :published,
  is_premium: true,
  price: 150.00
)

novel_2 = Novel.create!(
  user: author,
  title: "บันทึกลับระบบสุ่มกาชา",
  pen_name: "อาจารย์ A",
  description: "เมื่อโชคชะตาขึ้นอยู่กับเกลือ...",
  status: :published,
  is_premium: false, # เรื่องนี้อ่านฟรี
  price: 0.00
)
novel_1.genres << Genre.find_by(name: "fantasy")
novel_1.genres << Genre.find_by(name: "action")
novel_2.genres << Genre.find_by(name: "comedy")

puts "📄 สร้างตอนจำลอง (Chapters)..."
Chapter.create!(novel: novel_1, chapter_no: 1, title: "จุดเริ่มต้น", price: 0) # ตอนแรกให้อ่านฟรี
Chapter.create!(novel: novel_1, chapter_no: 2, title: "พลังที่ตื่นขึ้น", price: 10) # ติดเหรียญ 10 บาท
Chapter.create!(novel: novel_1, chapter_no: 3, title: "บททดสอบ", price: 15) # ติดเหรียญ 15 บาท

Chapter.create!(novel: novel_2, chapter_no: 1, title: "เกลือล้วนๆ", price: 0)

puts "🎉 สร้างข้อมูลจำลอง เสร็จสมบูรณ์!"
puts "-------------------------------------------"
puts "📌 ข้อมูลสำหรับ Login ใน Postman:"
puts "คนอ่าน (เอาไว้เทสซื้อ)   -> Email: reader@capstone.com / Pass: password123"
puts "นักเขียน (เอาไว้รับ 60%) -> Email: writer@capstone.com / Pass: password123"
puts "เสี่ย (เอาไว้รับ 40%) -> Email: admin@capstone.com  / Pass: password123"
puts "-------------------------------------------"