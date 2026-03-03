# == Schema Information
#
# Table name: videos
#
#  id             :bigint           not null, primary key
#  analysis_end   :string
#  analysis_start :string
#  notes          :text
#  processed_at   :datetime
#  source         :integer          default("camera"), not null
#  status         :integer          default("uploaded"), not null
#  title          :string
#  uploaded_at    :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_videos_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Video < ApplicationRecord
  TIME_CODE_FORMAT = /\A(?:\d{1,2}:)?\d{1,2}:\d{2}(?:\.\d+)?\z/.freeze

  belongs_to :user

  has_one_attached :original_video
  has_one_attached :processed_video

  has_many :analyses, dependent: :destroy
  has_one :conversation, dependent: :destroy

  enum :source, { camera: 0, library: 1 }
  enum :status, { uploaded: 0, processing: 1, analyzed: 2, failed: 3 }

  validates :source, presence: true
  validates :status, presence: true
  validates :notes, presence: true, if: -> { original_video.attached? }
  validates :analysis_start, format: { with: TIME_CODE_FORMAT, message: "must be HH:MM:SS or MM:SS" }, allow_blank: true
  validates :analysis_end, format: { with: TIME_CODE_FORMAT, message: "must be HH:MM:SS or MM:SS" }, allow_blank: true
  validate :analysis_end_after_start

  private

  def analysis_end_after_start
    return if analysis_start.blank? || analysis_end.blank?

    start_sec = parse_timecode(analysis_start)
    end_sec = parse_timecode(analysis_end)
    return if start_sec.nil? || end_sec.nil?
    return if end_sec > start_sec

    errors.add(:analysis_end, "must be after start time")
  end

  def parse_timecode(value)
    return nil if value.blank?
    parts = value.to_s.strip.split(":")
    case parts.length
    when 1
      parts[0].to_f
    when 2
      (parts[0].to_f * 60) + parts[1].to_f
    when 3
      (parts[0].to_f * 3600) + (parts[1].to_f * 60) + parts[2].to_f
    else
      nil
    end
  rescue ArgumentError, TypeError
    nil
  end
end
