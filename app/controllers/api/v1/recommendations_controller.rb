class Api::V1::RecommendationsController < ::ApplicationController
  before_action -> { authorize_request(optional: true) }

  def index
    if @current_user
      novels = personalized_recommendations
    else
      novels = popular_novels
    end

    render json: serialize_novels(novels)
  end

  private

  def personalized_recommendations
    seed_ids = collect_seed_novel_ids
    return popular_novels if seed_ids.empty?

    similar_novels = []

    seed_ids.each do |novel_id|
      results = CapstoneAiService.search_by_novel(novel_id, 5)
      results.each do |r|
        similar_novels << r[:novel_id] if r[:novel_id] != novel_id
      end
    end

    similar_novel_ids = similar_novels.uniq.first(12)
    return popular_novels if similar_novel_ids.empty?

    Novel.where(id: similar_novel_ids, status: :published)
         .includes(:genres)
         .sort_by { |n| similar_novel_ids.index(n.id) }
  end

  def collect_seed_novel_ids
    ids = []

    ids += ReadingHistory.where(user_id: @current_user.id)
                         .order(updated_at: :desc)
                         .limit(10)
                         .pluck(:novel_id)

    ids += ChapterLike.where(user_id: @current_user.id)
                      .order(created_at: :desc)
                      .limit(10)
                      .pluck(:novel_id)

    ids += Follow.where(user_id: @current_user.id)
                 .limit(10)
                 .pluck(:novel_id)

    own_ids = Novel.where(user_id: @current_user.id).pluck(:id)
    ids.uniq - own_ids
  end

  def popular_novels
    novel_ids = ChapterView.where.not(novel_id: nil)
                           .group(:novel_id)
                           .order('count_all DESC')
                           .limit(12)
                           .count
                           .keys

    Novel.where(id: novel_ids, status: :published)
         .includes(:genres)
         .sort_by { |n| novel_ids.index(n.id) }
  end

  def serialize_novels(novels)
    novel_ids = novels.map(&:id)
    likes_by_novel = ChapterLike.where(novel_id: novel_ids).group(:novel_id).count
    views_by_novel = ChapterView.where(novel_id: novel_ids).group(:novel_id).count

    novels.map do |novel|
      novel.as_json(include: :genres).merge(
        view_count: views_by_novel[novel.id] || 0,
        like_count: likes_by_novel[novel.id] || 0,
        tags: novel.tags || []
      )
    end
  end
end
