class FollowersController < ApplicationController
  swagger_controller :followers, "Followers management"

  skip_before_filter :verify_authenticity_token

  before_action :authenticate_volunteer!, unless: :is_swagger_request?

  before_action :set_assoc
  before_action :set_target_volunteer, only: [:block]
  before_action :check_rights, only: [:block]

  swagger_api :follow do
    summary "Follow an association"
    param :header, 'access-token', :string, :required, "Access token"
    param :header, :client, :string, :required, "Client token"
    param :header, :uid, :string, :required, "Volunteer's uid (email address)"
    param :query, :assoc_id, :integer, :required, "Association's id"
    response :ok
  end
  def follow
    begin
      link = AvLink.where(volunteer_id: current_volunteer.id,
                          assoc_id: @assoc.id,
                          rights: 'follower').first
      if link.eql?(nil)
        AvLink.create!(volunteer_id: current_volunteer.id,
                       assoc_id: @assoc.id,
                       rights: 'follower')
        render :json => create_response(t("follower.success.following")) and return
      elsif link.level.eql?(-1)
        render :json => create_error(400, t("follower.failure.blocked")) and return
      else
        render :json => create_error(400, t("follower.failure.exists")) and return
      end
    rescue => e
      render :json => create_error(400, e.to_s)
    end
  end

  swagger_api :unfollow do
    summary "Unfollow an association"
    param :header, 'access-token', :string, :required, "Access token"
    param :header, :client, :string, :required, "Client token"
    param :header, :uid, :string, :required, "Volunteer's uid (email address)"
    param :query, :assoc_id, :integer, :required, "Association's id"
    response :ok
  end
  def unfollow
    begin
      link = AvLink.where(volunteer_id: current_volunteer.id,
                          assoc_id: @assoc.id).first
      if link.eql?(nil)
        render :json => create_error(400, t("follower.failure.nil")) and return
      elsif link.level > 0
        render :json => create_error(400, t("follower.failure.high_level")) and return
      elsif link.level.eql?(-1)
        render :json => create_error(400, t("follower.failure.blocked")) and return
      else
        link.destroy
        render :json => create_response(t("follower.success.unfollowing")) and return
      end
    rescue => e
      render :json => create_error(400, e.to_s)
    end
  end

  swagger_api :block do
    summary "Block a follower"
    param :header, 'access-token', :string, :required, "Access token"
    param :header, :client, :string, :required, "Client token"
    param :header, :uid, :string, :required, "Volunteer's uid (email address)"
    param :query, :assoc_id, :integer, :required, "Association's id"
    param :query, :volunteer_id, :integer, :required, "Volunteer's id"
    response :ok
  end
  def block
    begin
      link = AvLink.where(volunteer_id: @target_volunteer.id, assoc_id: @assoc.id).first
      if link.eql?(nil)
        render :json => create_error(400, t("follower.failure.target_nil")) and return
      elsif link.level > 0
        render :json => create_error(400, t("follower.failure.target_high_level")) and return
      elsif link.level.eql?(-1)
        render :json => create_error(400, t("follower.failure.target_blocked")) and return
      else
        link.rights = "block"
        link.save!
        render :json => create_response(t("follower.success.blocked")) and return
      end
    rescue => e
      render :json => create_error(400, e.to_s)
    end
  end

  private
  def set_assoc
    begin
      @assoc = Assoc.find_by!(id: params[:assoc_id])
    rescue
      render :json => create_error(400, t("assocs.failure.id")) and return
    end
  end

  def set_target_volunteer
    begin
      @target_volunteer = Volunteer.find_by!(id: params[:volunteer_id])
    rescue
      render :json => create_error(400, t("volunteers.failure.id")) and return
    end
  end

  def check_rights
    link = AvLink.where(volunteer_id: current_volunteer.id, assoc_id: @assoc.id).first
    if link.eql?(nil) or link.level < 2
      render :json => create_error(400, t("follower.failure.rights")) and return
    end
  end
end
