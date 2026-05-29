class LanguageDetector
  THAI_RANGE = (0x0E00..0x0E7F).freeze

  def self.detect(content)
    return 'th' if content.blank?

    # Strip HTML tags
    plain_text = content.to_s.gsub(/<[^>]*>/, '')
    return 'th' if plain_text.blank?

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

    if thai_count > 0 && eng_count > 0
      'th-en'
    elsif thai_count > 0
      'th'
    elsif eng_count > 0
      'en'
    else
      'th'
    end
  end

  def self.detect_from_chapters(chapters_content)
    combined = Array(chapters_content).join(' ')
    detect(combined)
  end
end
