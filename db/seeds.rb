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