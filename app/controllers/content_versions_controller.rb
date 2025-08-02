class ContentVersionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_content_repository
  before_action :set_content_version, only: [:show, :edit, :update, :destroy, :diff, :revert, :preview, :approve, :reject]

  def index
    @content_versions = @content_repository.content_versions
                                          .includes(:author)
                                          .ordered
                                          .page(params[:page])
                                          .per(params[:per_page] || 20)
  end

  def show
    @diff_data = @content_version.diff_from_previous if @content_version.previous_version
    
    respond_to do |format|
      format.html
      format.json do
        render json: @content_version.to_json(
          include: :author,
          methods: [:diff_from_previous, :is_latest?]
        )
      end
    end
  end

  def new
    @content_version = @content_repository.content_versions.build
    @current_version = @content_repository.current_version
  end

  def create
    version_number = (@content_repository.current_version&.version_number || 0) + 1
    
    @content_version = @content_repository.content_versions.build(content_version_params)
    @content_version.author = current_user
    @content_version.version_number = version_number

    if @content_version.save
      redirect_to [@content_repository, @content_version], notice: 'Version was successfully created.'
    else
      @current_version = @content_repository.current_version
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Editing creates a new version based on this one
    @new_version = @content_repository.content_versions.build(
      body: @content_version.body,
      commit_message: ""
    )
  end

  def update
    # Updates always create new versions, never modify existing ones
    version_number = (@content_repository.current_version&.version_number || 0) + 1
    
    @new_version = @content_repository.content_versions.build(content_version_params)
    @new_version.author = current_user
    @new_version.version_number = version_number

    if @new_version.save
      redirect_to [@content_repository, @new_version], notice: 'New version was successfully created.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Only allow deletion of latest version if not published
    if @content_version.is_latest? && @content_repository.status != 'published'
      @content_version.destroy
      redirect_to [@content_repository, :content_versions], notice: 'Version was successfully deleted.'
    else
      redirect_to [@content_repository, @content_version], alert: 'Cannot delete this version.'
    end
  end

  def diff
    @previous_version = @content_version.previous_version
    @diff_data = @content_version.diff_from_previous
    
    unless @diff_data
      redirect_to [@content_repository, @content_version], alert: 'No previous version to compare with.'
      return
    end

    respond_to do |format|
      format.html
      format.json { render json: @diff_data }
    end
  end

  def revert
    begin
      @content_version.revert_to!
      redirect_to @content_repository, notice: "Successfully reverted to version #{@content_version.version_number}."
    rescue => e
      redirect_to [@content_repository, @content_version], alert: "Failed to revert: #{e.message}"
    end
  end

  def preview
    render layout: 'preview'
  end

  def approve
    approval = @content_repository.content_approvals.build(
      user: current_user,
      content_version: @content_version,
      status: 'approved',
      comments: params[:comments]
    )

    if approval.save
      # Update repository status if this brings it to approved state
      if @content_version.is_latest? && sufficient_approvals?
        @content_repository.update(status: 'approved')
      end
      
      redirect_to [@content_repository, @content_version], 
                  notice: 'Version was successfully approved.'
    else
      redirect_to [@content_repository, @content_version], 
                  alert: 'Failed to approve version.'
    end
  end

  def reject
    approval = @content_repository.content_approvals.build(
      user: current_user,
      content_version: @content_version,
      status: 'rejected',
      comments: params[:comments]
    )

    if approval.save && @content_version.is_latest?
      @content_repository.update(status: 'rejected')
      redirect_to [@content_repository, @content_version], 
                  notice: 'Version was rejected.'
    else
      redirect_to [@content_repository, @content_version], 
                  alert: 'Failed to reject version.'
    end
  end

  private

  def set_content_repository
    @content_repository = ContentRepository.accessible_by(current_user).find(params[:content_repository_id])
  end

  def set_content_version
    @content_version = @content_repository.content_versions.find(params[:id])
  end

  def content_version_params
    params.require(:content_version).permit(:body, :commit_message)
  end

  def sufficient_approvals?
    # Simple approval logic - can be customized based on workflow requirements
    required_approvals = @content_repository.campaign&.required_approvals || 1
    current_approvals = @content_repository.content_approvals
                                          .where(content_version: @content_version, status: 'approved')
                                          .count
    current_approvals >= required_approvals
  end
end