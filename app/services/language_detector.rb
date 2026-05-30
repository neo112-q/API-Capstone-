class LanguageDetector
  THAI_RANGE = (0x0E00..0x0E7F).freeze

  def self.detect(content)
    return nil if content.blank?

    plain_text = content.to_s.gsub(/<[^>]*>/, '')
    return nil if plain_text.strip.blank?

    thai_count = 0
    eng_count = 0

    plain_text.each_char do |char|
      code = char.ord
      if THAI_RANGE.include?(code)
        thai_count += 1
      elsif char.match?(/[a-zA-Z]/)
        eng_count += 1
      end
    end

    min_chars = 5
    has_thai = thai_count >= min_chars
    has_eng  = eng_count >= min_chars

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
