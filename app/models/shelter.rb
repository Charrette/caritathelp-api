class Shelter < ActiveRecord::Base
  serialize :tags, Array

  belongs_to :assoc

  before_create :set_default_picture

  validates :name, presence: true, :on => :create
  validates :address, presence: true, :on => :create
  validates :zipcode, presence: true, :on => :create
  validates :city, presence: true, :on => :create
  validates :total_places, :numericality => { :greater_than_or_equal_to => 0},
  presence: true, :on => :create
  validates :free_places, :numericality => { :greater_than_or_equal_to => 0},
  presence: true, :on => :create
  validate :if_free_correct
  validates_format_of :phone, with: /\A0[1-7]([-\/. ]?[0-9]{2}){4}\Z/i, allow_blank: true
  validates_format_of :mail, with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, allow_blank: true

  def set_default_picture
    self.thumb_path = Rails.application.config.default_shelter
  end

  private

  def if_free_correct
    errors.add(:free_places, "doit être inférieur ou égal à total_places") unless
      free_places != nil and total_places != nil and free_places <= total_places
  end
end
