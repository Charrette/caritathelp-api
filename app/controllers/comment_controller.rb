class CommentController < ApplicationController
  swagger_controller :comments, "Comments management"

  before_filter :check_token
  before_action :set_volunteer
  before_action :set_new, only: [:create]
  before_action :set_comment, only: [:update, :delete, :show]
  before_action :check_rights, except: [:create]

  swagger_api :create do
    summary "Creates a comment linked to the new"
    param :query, :token, :string, :required, "Your token"
    param :query, :content, :string, :required, "Content of the comment"
    param :query, :new_id, :integer, :required, "New's id"
    response :ok
    response 400
  end
  def create
    begin
      unless @new.concerns_user?(@volunteer)
        render :json => create_error(400, t("comments.failure.rights")) and return
      end
      new_comment = Comment.create!([new_id: @new.id, volunteer_id: @volunteer.id,
                                     content: params[:content]]).first
      render :json => create_response(new_comment.as_json.merge(
                                       thumb_path: @volunteer.thumb_path,
                                       firstname: @volunteer.firstname,
                                       lastname: @volunteer.lastname))
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      render :json => create_error(400, e.to_s) and return
    end
  end

  swagger_api :update do
    summary "Update the comment referred by id"
    param :path, :id, :integer, :required, "Comment's id"
    param :query, :token, :string, :required, "Your token"
    param :query, :content, :string, :required, "Content of the comment"
    response :ok
    response 400
  end
  def update
    begin
      if @comment.volunteer_id != @volunteer.id
        render :json => create_error(400, t("comments.failure.rights")) and return        
      end
      # changer le permit
      @comment.update!(params.permit(:content))
      render :json => create_response(@comment.as_json.merge(thumb_path: @volunteer.thumb_path,
                                                             firstname: @volunteer.firstname,
                                                             lastname: @volunteer.lastname))
    rescue Exception => e
      render :json => create_error(400, e.to_s) and return
    end
  end

  swagger_api :show do
    summary "Returns the comment's information"
    param :path, :id, :integer, :required, "Comment's id"
    param :query, :token, :string, :required, "Your token"
    response :ok
    response 400
  end
  def show
    render :json => create_response(@comment.as_json
                                     .merge(thumb_path: @comment.volunteer.thumb_path,
                                            firstname: @comment.volunteer.firstname,
                                            lastname: @comment.volunteer.lastname))
  end

  swagger_api :delete do
    summary "Delete the comment"
    param :path, :id, :integer, :required, "Comment's id"
    param :query, :token, :string, :required, "Your token"
    response :ok
    response 400
  end
  def delete
    unless @comment.new.volunteer_id == @volunteer.id # allow new's creator to remove all comments
      if @comment.volunteer_id != @volunteer.id
        render :json => create_error(400, t("comments.failure.rights")) and return        
      end
    end
    @comment.destroy
    render :json => create_response(t("comments.success.deleted"))
  end

  private
  def set_volunteer
    @volunteer = Volunteer.find_by(token: params[:token])
  end

  def set_comment
    begin
      @comment = Comment.find(params[:id])
      @new = New.find(@comment.new_id)
    rescue
      render :json => create_error(400, t("comments.failure.id"))
    end
  end

  def set_new
    begin
      @new = New.find(params[:new_id])
    rescue
      render :json => create_error(400, t("news.failure.id"))
    end
  end

  def check_rights
    if @new.private
      level = @volunteer.av_links.find_by(assoc_id: @new.group_id).try(:level) if @new.group_type == "Assoc"
      level = @volunteer.event_volunteers.find_by(event_id: @new.group_id).try(:level) if @new.group_type == "Event"
      if ((@new.group_type == "Assoc" and (level.blank? or level < AvLink.levels["member"])) || (@new.group_type == "Event" and (level.blank? or level < EventVolunteer.levels["member"])) || (@new.group_type == "Volunteer" and @volunteer.v_friends.find_by(friend_volunteer_id: @new.group_id)))
        render json: create_error(400, t("volunteers.failure.rights"))
      end
    end
  end
end
