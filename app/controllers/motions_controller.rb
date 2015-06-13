class MotionsController < GroupBaseController
  before_filter :load_resource_by_key, except: [:create, :index]
  authorize_resource except: [:create, :index, :show, :update_outcome, :create_outcome]
  before_filter :authenticate_user!, except: [:show, :index]

  def create
    @discussion = Discussion.find(params[:motion][:discussion_id])
    if @discussion.current_motion
      redirect_to @discussion
      flash[:error] = t(:"error.proposal_already_exists")
    else
      @motion = Motion.new(permitted_params.motion)
      @group = @discussion.group

      if MotionService.create(motion: @motion,
                              actor: current_user)
        Measurement.increment('motions.create.success')
        flash[:success] = t("success.proposal_created")
        redirect_to @discussion
      else
        Measurement.increment('motions.create.error')
        flash[:warning] = t("warning.proposal_not_created")
        render action: :new
      end
    end
  end

  def index
    if params[:group_id].present?
      @group = Group.friendly.find(params[:group_id])
      if cannot? :show, @group
        head 401
      else
        @closed_motions = @group.motions.closed.page(params[:page])
        render layout: false if request.xhr?
      end
    else
      authenticate_user!
      @closed_motions= current_user.motions.closed.page(params[:page])
      render layout: false if request.xhr?
    end
  end

  def edit
    @group = @motion.group
  end

  def update
    MotionService.update(motion: @motion,
                         params: permitted_params.motion,
                         actor: current_user)
    redirect_to @motion
  end

  def history
  end

  def show
    redirect_to discussion_url(@motion.discussion, proposal: @motion)
  end

  def destroy
    @motion.destroy
    redirect_to group_url(@motion.group)
    flash[:success] = t("success.proposal_deleted")
  end

  def close
    MotionService.close_by_user(@motion, current_user)
    flash[:success] = t("success.motion_closed")
    redirect_to discussion_url(@motion.discussion, proposal: @motion)
  end

  def create_outcome
    if MotionService.create_outcome(motion: @motion,
                                    params: permitted_params.motion,
                                    actor: current_user)
      flash[:success] = t("success.motion_outcome_created")
    else
      flash[:error] = t("error.motion_outcome_not_created")
    end
    redirect_to discussion_url(@motion.discussion, proposal: @motion)
  end

  def update_outcome
    if MotionService.update_outcome(motion: @motion, 
                                    params: permitted_params.motion, 
                                    actor: current_user)
      flash[:success] = t("success.motion_outcome_updated")
    else
      flash[:error] = t("error.motion_outcome_not_updated")
    end
    redirect_to discussion_url(@motion.discussion, proposal: @motion)
  end

  private
    def load_resource_by_key
      @motion ||= Motion.find_by_key!(params[:id])
    end

    def find_group
      if (params[:id] && (params[:id] != "new"))
        Motion.find_by_key!(params[:id]).group
      elsif params[:motion][:discussion_id]
        Discussion.find(params[:motion][:discussion_id]).group
      end
    end
end
