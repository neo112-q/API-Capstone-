class Api::V1::TagsController < ::ApplicationController
  def popular
    tags = Novel.where(status: :published)
                .where.not(tags: nil)
                .where("array_length(tags, 1) > 0")
                .pluck(:tags)
                .flatten
                .map { |t| t.is_a?(Hash) ? (t['name'] || t[:name]) : t }
                .compact
                .select { |t| t.present? }
                .group_by(&:itself)
                .transform_values(&:count)
                .sort_by { |_, v| -v }
                .first(10)
                .map { |name, count| { name: name, count: count } }

    render json: { tags: tags }
  end
end
