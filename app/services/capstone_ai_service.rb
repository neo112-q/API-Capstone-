require 'net/http'
require 'json'
require 'uri'

class CapstoneAiService
  API_BASE = ENV.fetch('CAPSTONE_AI_URL', 'http://localhost:9922')
  API_PREFIX = '/api/v1'

  def self.index_chapter(novel, chapter, content)
    return if api_base.blank?

    body = {
      novelId: novel.id,
      chapter: chapter.chapter_no,
      novelName: novel.title,
      chapterName: chapter.title || "Chapter #{chapter.chapter_no}",
      novelContent: content,
      tags: novel.tags || []
    }

    post("#{API_PREFIX}/chapters", body)
  rescue => e
    Rails.logger.warn "[CapstoneAI] index_chapter failed: #{e.message}"
  end

  def self.search_by_novel(novel_id, top_k = 5)
    return [] if api_base.blank?

    data = get("#{API_PREFIX}/search/novel/#{novel_id}?k=#{top_k}")
    results = data.dig('data', 'results') || []
    results.map { |r| { novel_id: r['novel_id'], chapter: r['chapter'], novel_name: r['novel_name'], chapter_name: r['chapter_name'], tags: r['tags'], score: r['score'] } }
  rescue => e
    Rails.logger.warn "[CapstoneAI] search_by_novel failed: #{e.message}"
    []
  end

  def self.search_by_keyword(keyword, top_k = 20)
    return [] if api_base.blank?

    encoded = URI.encode_www_form_component(keyword)
    data = get("#{API_PREFIX}/search/keyword?keyword=#{encoded}&k=#{top_k}")
    results = data.dig('data', 'results') || []
    results.map { |r| { novel_id: r['novel_id'], chapter: r['chapter'], novel_name: r['novel_name'], chapter_name: r['chapter_name'], tags: r['tags'], score: r['score'] } }
  rescue => e
    Rails.logger.warn "[CapstoneAI] search_by_keyword failed: #{e.message}"
    []
  end

  def self.delete_novel(novel_id)
    return if api_base.blank?

    delete("#{API_PREFIX}/novels/#{novel_id}")
  rescue => e
    Rails.logger.warn "[CapstoneAI] delete_novel failed: #{e.message}"
  end

  def self.delete_chapter(novel_id, chapter_no)
    return if api_base.blank?

    delete("#{API_PREFIX}/chapters/#{novel_id}/#{chapter_no}")
  rescue => e
    Rails.logger.warn "[CapstoneAI] delete_chapter failed: #{e.message}"
  end

  def self.health
    return nil if api_base.blank?

    get("#{API_PREFIX}/health")
  rescue => e
    Rails.logger.warn "[CapstoneAI] health check failed: #{e.message}"
    nil
  end

  private

  def self.api_base
    API_BASE
  rescue
    nil
  end

  def self.get(path)
    uri = URI("#{API_BASE}#{path}")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end

  def self.post(path, body_hash)
    uri = URI("#{API_BASE}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request.body = body_hash.to_json
    response = http.request(request)
    JSON.parse(response.body)
  end

  def self.delete(path)
    uri = URI("#{API_BASE}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Delete.new(uri.path)
    http.request(request)
  end
end
