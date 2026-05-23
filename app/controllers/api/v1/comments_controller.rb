# app/controllers/api/v1/comments_controller.rb
module Api
  module V1
    class CommentsController < ::ApplicationController
      before_action :authorize_request, except: [:index]
      before_action :set_chapter, only: [:index, :create]

      # GET /api/v1/novels/:novel_id/chapters/:chapter_id/comments
      def index
        comments = @chapter.comments.includes(:user).order(created_at: :desc)
        
        page = params[:page].to_i
        page = 1 if page < 1
        limit = params[:limit].to_i
        limit = 10 if limit <= 0
        offset = (page - 1) * limit
        
        paginated_comments = comments.limit(limit).offset(offset)
        
        # ✅ แก้ไขตรงนี้: ห่อด้วย { comments: ... }
        render json: {
            comments: paginated_comments.as_json(
            only: [:id, :content, :created_at],
            include: {
                user: { only: [:id, :username, :avatar_path] }
            }
            ),
            total: comments.count,
            page: page,
            total_pages: (comments.count.to_f / limit).ceil
        }, status: :ok
      end

      # POST /api/v1/novels/:novel_id/chapters/:chapter_id/comments
      def create
        comment = @chapter.comments.build(comment_params)
        comment.user = @current_user
        comment.novel_id = @chapter.novel_id
        comment.chapter_no = @chapter.chapter_no

        if comment.save
          render json: {
            message: "คอมเมนต์สำเร็จ",
            comment: comment.as_json(
              only: [:id, :content, :created_at],
              include: { user: { only: [:id, :username, :avatar_path] } }
            )
          }, status: :created
        else
          render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/novels/:novel_id/chapters/:chapter_id/comments/:id
      def destroy
        comment = Comment.find_by(id: params[:id])
        
        if comment.nil?
          return render json: { error: "ไม่พบคอมเมนต์" }, status: :not_found
        end

        # ✅ เจ้าของคอมเมนต์ หรือ เจ้าของนิยาย หรือ Admin เท่านั้นที่ลบได้
        is_owner = comment.user_id == @current_user.id
        is_novel_owner = Novel.find(comment.novel_id).user_id == @current_user.id
        is_admin = @current_user.admin?

        unless is_owner || is_novel_owner || is_admin
          return render json: { error: "ไม่มีสิทธิ์ลบคอมเมนต์นี้" }, status: :forbidden
        end

        comment.destroy
        render json: { message: "ลบคอมเมนต์เรียบร้อยแล้ว" }, status: :ok
      end

      private

      def set_chapter
        @chapter = Chapter.find_by(
          novel_id: params[:novel_id], 
          chapter_no: params[:chapter_id]
        )
        
        if @chapter.nil?
          render json: { error: "ไม่พบตอนนิยายนี้" }, status: :not_found
        end
      end

      def comment_params
        params.require(:comment).permit(:content)
      end
    end
  end
end