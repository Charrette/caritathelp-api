class Event < ActiveRecord::Base
  has_and_belongs_to_many :volunteers, join_table: :event_volunteers
  has_many :event_volunteers, dependent: :destroy

  belongs_to :assoc

  has_many :news, as: :group, class_name: 'New'

  before_create :set_default_picture

  validates :title, presence: true, :on => :create
  validates :description, presence: true, :on => :create
  validates :assoc_id, presence: true, :on => :create
  validates :begin, presence: true, :on => :create
  validates :end, presence: true, :on => :create
  validate :are_dates_corrects?#, if: lambda { |event| event.begin.present? or event.end.present? }

  def public
    !self.private
  end

  def set_default_picture
    self.thumb_path = Rails.application.config.logo
  end

  def are_dates_corrects?
  	if self.begin.blank?
      self.errors.add(:begin, "Date de début invalide") and return false
  	end
  	if self.end.blank?
      self.errors.add(:end, "Date de fin invalide") and return false
  	end
    if self.begin < Time.now
      self.errors.add(:begin, "Ne peut être antérieur à maintenant") and return false
    end
    if self.end < self.begin
      self.errors.add(:end, "Ne peut être antérieur à la date de début") and return false
    end
  end
end
