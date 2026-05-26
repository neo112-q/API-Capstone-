class Api::V1::TagsController < ::ApplicationController
  def popular
    tags = Novel.where(status: :published)
                .where.not(tags: nil)
                .where("array_length(tags, 1) > 0")
                .pluck(:tags)
                .flatten
                .group_by(&:itself)
                .transform_values(&:count)
                .sort_by { |_, v| -v }
                .first(30)
                .map(&:first)

    render json: { tags: tags }
  end
end
