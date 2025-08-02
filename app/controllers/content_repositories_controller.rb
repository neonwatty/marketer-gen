class ContentRepositoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_content_repository, only: [:show, :edit, :update, :destroy, :preview, :duplicate, :publish, :archive, :analytics, :collaboration, :regenerate]

  def index
    @q = ContentRepository.includes(:user, :campaign, :content_versions)
                         .accessible_by(current_user)
                         .ransack(params[:q])
    
    @content_repositories = @q.result
                             .page(params[:page])
                             .per(params[:per_page] || 12)
    
    @stats = {
      total: ContentRepository.accessible_by(current_user).count,
      draft: ContentRepository.accessible_by(current_user).draft.count,
      review: ContentRepository.accessible_by(current_user).review.count,
      published: ContentRepository.accessible_by(current_user).published.count
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @content_repositories.to_json(include: [:user, :current_version]) }
    end
  end

  def show
    @current_version = @content_repository.current_version
    @versions = @content_repository.content_versions.includes(:author).ordered.limit(10)
    @approvals = @content_repository.content_approvals.includes(:user).recent.limit(5)
    @tags = @content_repository.content_tags.includes(:user)
    
    respond_to do |format|
      format.html
      format.json do
        render json: @content_repository.to_json(
          include: {
            current_version: { include: :author },
            content_versions: { include: :author, limit: 10 },
            content_approvals: { include: :user, limit: 5 },
            content_tags: { include: :user }
          }
        )
      end
    end
  end

  def new
    @content_repository = ContentRepository.new
    @campaigns = current_user.accessible_campaigns
    @content_types = ContentRepository.content_types.keys
    @formats = ContentRepository.formats.keys
  end

  def create
    @content_repository = ContentRepository.new(content_repository_params)
    @content_repository.user = current_user

    if @content_repository.save
      # Create initial version
      @content_repository.create_version!(
        body: params[:content_repository][:body] || "",
        author: current_user,
        commit_message: "Initial version"
      )
      
      redirect_to @content_repository, notice: 'Content was successfully created.'
    else
      @campaigns = current_user.accessible_campaigns
      @content_types = ContentRepository.content_types.keys
      @formats = ContentRepository.formats.keys
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @campaigns = current_user.accessible_campaigns
    @content_types = ContentRepository.content_types.keys
    @formats = ContentRepository.formats.keys
    @current_version = @content_repository.current_version
  end

  def update
    if @content_repository.update(content_repository_params)
      # Create new version if body content changed
      if params[:content_repository][:body].present? && 
         @content_repository.current_version&.body != params[:content_repository][:body]
        @content_repository.create_version!(
          body: params[:content_repository][:body],
          author: current_user,
          commit_message: params[:commit_message] || "Updated content"
        )
      end
      
      redirect_to @content_repository, notice: 'Content was successfully updated.'
    else
      @campaigns = current_user.accessible_campaigns
      @content_types = ContentRepository.content_types.keys
      @formats = ContentRepository.formats.keys
      @current_version = @content_repository.current_version
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @content_repository.destroy
    redirect_to content_repositories_url, notice: 'Content was successfully deleted.'
  end

  def preview
    @current_version = @content_repository.current_version
    render layout: 'preview'
  end

  def duplicate
    new_repository = @content_repository.dup
    new_repository.title = "#{@content_repository.title} (Copy)"
    new_repository.user = current_user
    new_repository.status = 'draft'
    
    if new_repository.save
      # Copy current version
      current_version = @content_repository.current_version
      if current_version
        new_repository.create_version!(
          body: current_version.body,
          author: current_user,
          commit_message: "Duplicated from #{@content_repository.title}"
        )
      end
      
      redirect_to new_repository, notice: 'Content was successfully duplicated.'
    else
      redirect_to @content_repository, alert: 'Failed to duplicate content.'
    end
  end

  def publish
    if @content_repository.can_be_published?
      @content_repository.update(status: 'published', published_at: Time.current)
      redirect_to @content_repository, notice: 'Content was successfully published.'
    else
      redirect_to @content_repository, alert: 'Content cannot be published in its current state.'
    end
  end

  def archive
    if @content_repository.can_be_archived?
      @content_repository.update(status: 'archived', archived_at: Time.current)
      redirect_to @content_repository, notice: 'Content was successfully archived.'
    else
      redirect_to @content_repository, alert: 'Content cannot be archived in its current state.'
    end
  end

  def analytics
    @analytics_data = ContentAnalyticsService.new(@content_repository).generate_report
    render json: @analytics_data
  end

  def collaboration
    @collaborators = @content_repository.content_permissions.includes(:user)
    @activity_feed = @content_repository.content_revisions.includes(:user).recent.limit(20)
  end

  def regenerate
    # Integrate with AI service to regenerate content
    begin
      regenerated_content = ContentGenerationService.new(@content_repository).regenerate
      
      @content_repository.create_version!(
        body: regenerated_content,
        author: current_user,
        commit_message: "AI regenerated content"
      )
      
      redirect_to @content_repository, notice: 'Content was successfully regenerated.'
    rescue => e
      redirect_to @content_repository, alert: "Failed to regenerate content: #{e.message}"
    end
  end

  private

  def set_content_repository
    @content_repository = ContentRepository.accessible_by(current_user).find(params[:id])
  end

  def content_repository_params
    params.require(:content_repository).permit(
      :title, :description, :content_type, :format, :campaign_id,
      :target_audience, :keywords, :meta_data
    )
  end
end