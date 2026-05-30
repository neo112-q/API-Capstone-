class LanguageDetector
  THAI_RANGE = (0x0E00..0x0E7F).freeze
  THAI_RATIO_THRESHOLD = 0.15
  ENG_RATIO_THRESHOLD  = 0.15
  MIN_LINGUISTIC_CHARS = 10

  def self.detect(content)
    return nil if content.blank?

    plain_text = content.to_s.gsub(/<[^>]*>/, '').strip
    return nil if plain_text.blank?

    thai_count = 0
    eng_count  = 0

    plain_text.each_char do |char|
      code = char.ord
      if THAI_RANGE.include?(code)
        thai_count += 1
      elsif char.match?(/[a-zA-Z]/)
        eng_count += 1
      end
    end

    total = thai_count + eng_count
    return nil if total < MIN_LINGUISTIC_CHARS

    thai_ratio = thai_count.to_f / total
    eng_ratio  = eng_count.to_f  / total

    has_thai = thai_ratio >= THAI_RATIO_THRESHOLD
    has_eng  = eng_ratio  >= ENG_RATIO_THRESHOLD

    if has_thai && has_eng
      'th-en'
    elsif has_thai
      'th'
    elsif has_eng
      'en'
    else
      nil
    end
  end

  def self.detect_from_chapters(contents_array)
    combined = Array(contents_array).join(' ')
    detect(combined)
  end
end