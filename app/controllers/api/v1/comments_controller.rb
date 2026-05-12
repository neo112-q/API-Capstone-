module Api
  module V1
    class CommentsController < ::ApplicationController
      before_action(:authorize_request, except: [:index])
      before_action(:set_chapter, only: [:index, :create])

      # ดูทั้งหมดของตอนนั้น ๆ (ไม่ต้องล็อกอินก็ดูได้ค้าบ)
      def index()
        comments = @chapter.comments.includes(:user).order(created_at: :desc)
        render(json: comments.as_json(include: { user: { only: [:id, :username, :email] } }), status: :ok)
      end

      # สร้างคอมเมนต์ใหม่
      def create()
        comment = Comment.new(comment_params())
        comment.user = @current_user
        
        comment.novel_id = @chapter.novel_id
        comment.chapter_no = @chapter.chapter_no

        if comment.save()
          render(json: { message: "คอมเมนต์สำเร็จ", comment: comment }, status: :created)
        else
          render(json: { error: comment.errors.full_messages }, status: :unprocessable_entity)
        end
      end

      # ลบคอมเมนต์ (ลบได้เฉพาะคอมเมนต์ของตัวเองแก้แล้ว)
      def destroy()
        comment = Comment.find_by(id: params[:id])
        
        if comment.nil?
          return render(json: { error: "ไม่พบคอมเมนต์" }, status: :not_found)
        end

        if comment.user_id != @current_user.id
          return render(json: { error: "ไม่มีสิทธิ์ลบคอมเมนต์นี้" }, status: :forbidden)
        end

        comment.destroy()
        render(json: { message: "ลบคอมเมนต์เรียบร้อยแล้ว" }, status: :ok)
      end

      private

      def set_chapter()
        @chapter = Chapter.find_by(novel_id: params[:novel_id], chapter_no: params[:chapter_id])
        
        @chapter ||= Chapter.find_by(id: params[:chapter_id])

        if @chapter.nil?
          render(json: { error: "ไม่พบตอนนิยายนี้" }, status: :not_found)
        end
      end

      def comment_params()
        params.require(:comment).permit(:content)
      end
    end
  end
end