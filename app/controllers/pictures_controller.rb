class PicturesController < ApplicationController
  swagger_controller :pictures, "Pictures management"

  before_action :authenticate_volunteer!, unless: :is_swagger_request?

  before_action :set_picture, only: [:delete, :update]
  before_action :check_rights, only: [:create]

  swagger_api :create do
    summary "Upload picture on the server"
    notes "You need to chose between assoc_id, shelter_id & event_id"
    param :header, 'access-token', :string, :required, "Access token"
    param :header, :client, :string, :required, "Client token"
    param :header, :uid, :string, :required, "Volunteer's uid (email address)"
    param :form, :file, :string, :required, "File content (base64)"
    param :form, :filename, :string, :required, "Name to give to the file"
    param :form, :original_filename, :string, :required, "Original name of the file"
    param :form, :assoc_id, :integer, :optional, "Assoc's id"
    param :form, :event_id, :integer, :optional, "Event's id"
    param :form, :is_main, :boolean, :optional, "true to make it the main picture"
    response :ok
  end
  def create
    #check if file is within picture_path
    actual_params = Hash.new
    actual_params[:picture] = Hash.new
    actual_params[:picture][:picture_path] = Hash.new
    actual_params[:picture][:picture_path][:file] = picture_params[:file]
    actual_params[:picture][:picture_path][:filename] = picture_params[:filename]
    actual_params[:picture][:picture_path][:original_filename] = picture_params[:original_filename]
    actual_params[:picture][:is_main] = picture_params[:is_main]
    actual_params[:picture][:event_id] = picture_params[:event_id]
    actual_params[:picture][:assoc_id] = picture_params[:assoc_id]
    actual_params[:picture][:shelter_id] = picture_params[:shelter_id]

    if actual_params[:picture][:picture_path][:file]
      picture_path_params = actual_params[:picture][:picture_path]

      #create a new tempfile named fileupload
      tempfile = Tempfile.new("fileupload")
      tempfile.binmode

      #get the file and decode it with base64 then write it to the tempfile
      tempfile.write(Base64.decode64(picture_path_params[:file]))

      #create a new uploaded file
      uploaded_file = ActionDispatch::Http::UploadedFile
        .new(:tempfile => tempfile,
             :filename => picture_path_params[:filename],
             :original_filename => picture_path_params[:original_filename])

      #replace picture_path with the new uploaded file
      actual_params[:picture][:picture_path] =  uploaded_file
      actual_params[:picture][:volunteer_id] = current_volunteer.id

      # this section make sure that there's at least and only one main picture
      current_main_picture = nil
      if @event != nil
        current_main_picture = Picture.where(:volunteer_id => current_volunteer.id).where(:event_id => @event.id)
          .where(:is_main => true).first
      elsif @assoc != nil and @shelter != nil
        current_main_picture = Picture.where(:volunteer_id => current_volunteer.id)
          .where(:assoc_id => @assoc.id)
          .where(:shelter_id => @shelter.id)
          .where(:is_main => true).first
      elsif @assoc != nil
        current_main_picture = Picture.where(:volunteer_id => current_volunteer.id).where(:assoc_id => @assoc.id)
          .where(:is_main => true).first
      else
        current_main_picture = Picture.where(:volunteer_id => current_volunteer.id).where(:assoc_id => nil)
          .where(:event_id => nil).where(:is_main => true).first
      end
      if !current_main_picture.eql?(nil) && (actual_params[:picture][:is_main] == "true" or actual_params[:picture][:is_main] == true)
        begin
          current_main_picture.is_main = false
          current_main_picture.save!
        rescue
          render :json => create_error(400, t("pictures.failure.is_main")), status: 400
        end
      elsif current_main_picture.eql?(nil)
        actual_params[:picture][:is_main] = true
      else
        actual_params[:picture][:is_main] = false
      end
    end

    begin
      @picture = Picture.create!(actual_params[:picture])

      # this part extract the paths to make it easy to query them from anywhere
      path = @picture.picture_path.file.file
      thumb_path = @picture.picture_path.versions[:thumb].file.file
      index = path.index('/uploads')
      @picture.path = path[index..-1]
      index = thumb_path.index('/uploads')
      @picture.thumb_path = thumb_path[index..-1]
      @picture.save!

      set_main_picture(@picture)

      render :json => create_response(@picture)
    rescue ActiveRecord::RecordInvalid => e
      render :json => create_error(400, e.to_s), status: 400
    end
  end

  swagger_api :delete do
    summary "Delete picture"
    notes "Can't delete main picture"
    param :path, :id, :integer, :required, "Picture's id"
    param :header, 'access-token', :string, :required, "Access token"
    param :header, :client, :string, :required, "Client token"
    param :header, :uid, :string, :required, "Volunteer's uid (email address)"
    response :ok
  end
  def delete
    if @current_picture.event_id.eql?(nil) and @current_picture.assoc_id.eql?(nil) and @current_picture.volunteer_id != current_volunteer.id
      render :json => create_error(400, t("pictures.failure.rights")), status: 400 and return
    elsif @current_picture.event_id != nil
      link = EventVolunteer.where(:event_id => @current_picture.event_id)
        .where(:volunteer_id => current_volunteer.id).first
      if link.eql?(nil) or link.rights.eql?("guest")
        render :json => create_error(400, t("pictures.failure.rights")), status: 400 and return
      end
    elsif @current_picture.assoc_id != nil
      link = AvLink.where(:assoc_id => @current_picture.assoc_id)
        .where(:volunteer_id => current_volunteer.id).first
      if link.eql?(nil) or link.rights.eql?("member")
        render :json => create_error(400, t("pictures.failure.rights")), status: 400 and return
      end
    end
    if @current_picture.is_main
      render :json => create_error(400, t("pictures.failure.not_deleted")), status: 400
    else
      @current_picture.destroy
      render :json => create_response(t("pictures.success.deleted"))
    end
  end

  swagger_api :update do
    summary "Set picture as main picture"
    param :path, :id, :integer, :required, "Picture's id"
    param :header, 'access-token', :string, :required, "Access token"
    param :header, :client, :string, :required, "Client token"
    param :header, :uid, :string, :required, "Volunteer's uid (email address)"
    response :ok
  end
  def update
    if @current_picture.event_id.eql?(nil) and @current_picture.assoc_id.eql?(nil) and @current_picture.volunteer_id != current_volunteer.id
      render :json => create_error(400, t("pictures.failure.rights")), status: 400 and return
    elsif @current_picture.event_id != nil
      link = EventVolunteer.where(:event_id => @current_picture.event_id)
        .where(:volunteer_id => current_volunteer.id).first
      if link.eql?(nil) or link.rights.eql?("guest")
        render :json => create_error(400, t("pictures.failure.rights")), status: 400 and return
      end
    elsif @current_picture.assoc_id != nil
      link = AvLink.where(:assoc_id => @current_picture.assoc_id)
        .where(:volunteer_id => current_volunteer.id).first
      if link.eql?(nil) or link.rights.eql?("member")
        render :json => create_error(400, t("pictures.failure.rights")), status: 400 and return
      end
    end

    begin
      # downgrade the actual main picture
      if @current_picture.event_id != nil
        current_main_picture = Picture.where(:event_id => @current_picture.event_id)
          .where(:is_main => true).first
      elsif @current_picture.assoc_id != nil and @current_picture.shelter_id != nil
        current_main_picture = Picture.where(:assoc_id => @current_picture.assoc_id)
          .where(:shelter_id => @current_picture.shelter_id)
          .where(:is_main => true).first
      elsif @current_picture.assoc_id != nil
        current_main_picture = Picture.where(:assoc_id => @current_picture.assoc_id)
          .where(:is_main => true).first
      else
        current_main_picture = Picture.where(:volunteer_id => current_volunteer.id).where(:event_id => nil)
          .where(:assoc_id => nil).where(:is_main => true).first
      end
      if !current_main_picture.eql?(nil)
        current_main_picture.is_main = false
        current_main_picture.save!
      end

      @current_picture.update!({:is_main => true})

      set_main_picture(@current_picture)

      render :json => create_response(@current_picture)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      render :json => create_error(400, e.to_s), status: 400 and return
    end
  end

  private
  def picture_params
    params.permit(:is_main, :event_id, :assoc_id, :shelter_id, :file, :filename, :original_filename)
  end

  def set_picture
    begin
      @current_picture = Picture.find(params[:id])
    rescue
      render :json => create_error(400, t("pictures.failure.id")), status: 400 and return
    end
  end

  def set_main_picture(picture)
    begin
      if picture.is_main.eql?(true)
        if picture.event_id.present?
          event = Event.find_by(id: picture.event_id)
          event.update(thumb_path: picture.thumb_path) unless event.blank?
        elsif picture.assoc_id.present? and picture.shelter_id.present?
          shelter = Shelter.find_by(id: picture.shelter_id)
          shelter.update(thumb_path: picture.thumb_path) unless shelter.blank?
        elsif picture.assoc_id.present?
          assoc = Assoc.find_by(id: picture.assoc_id)
          assoc.update(thumb_path: picture.thumb_path) unless assoc.blank?
        else
          current_volunteer.thumb_path = picture.thumb_path
          current_volunteer.save!
        end
      end
    rescue => e
      render :json => create_error(400, e.to_s), status: 400 and return
    end
  end

  def check_rights
    if params[:event_id] == nil and params[:assoc_id] == nil and params[:shelter_id] == nil
      return true
    elsif params[:event_id] != nil and (params[:assoc_id] != nil or params[:shelter_id] != nil)
      render :json => create_error(400, t("pictures.failure.specify")), status: 400
      return false
    elsif params[:event_id] != nil
      begin
        @event = Event.find(params[:event_id])
        @link = EventVolunteer.where(:volunteer_id => current_volunteer.id)
          .where(:event_id => @event.id).first

        # if @link.eql?(nil) or @link.level < EventVolunteer.levels["admin"]
        if @link.eql?(nil) or @link.rights.eql?("member")
          render :json => create_error(400, t("events.failure.rights")), status: 400
          return false
        end
        return true
      rescue
        render :json => create_error(400, t("events.failure.id")), status: 400
      end
    elsif params[:shelter_id] != nil
      begin
        @shelter = Shelter.find(params[:shelter_id])
        @assoc = Assoc.find(@shelter.assoc_id)
        @link = AvLink.where(:volunteer_id => current_volunteer.id)
          .where(:assoc_id => @assoc.id).first

        # if @link.eql?(nil) or @link.level < AvLink.levels["admin"]
        if @link.eql?(nil) or @link.rights.eql?("member")
          render :json => create_error(400, t("assocs.failure.rights")), status: 400
          return false
        end
        return true
      rescue
        render :json => create_error(400, t("shelters.failure.id")), status: 400
      end
    elsif params[:assoc_id] != nil
      begin
        @assoc = Assoc.find(params[:assoc_id])
        @link = AvLink.where(:volunteer_id => current_volunteer.id)
          .where(:assoc_id => @assoc.id).first

        # if @link.eql?(nil) or @link.level < AvLink.levels["admin"]
        if @link.eql?(nil) or @link.rights.eql?("member")
          render :json => create_error(400, t("assocs.failure.rights")), status: 400
          return false
        end
        return true
      rescue => e
        render :json => create_error(400, e.to_s), status: 400
      end
    end
  end
end
