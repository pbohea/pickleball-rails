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
  TIME_CODE_FORMAT = /\A\d{1,2}:[0-5]\d\z/.freeze

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
  validates :analysis_start, presence: true, format: { with: TIME_CODE_FORMAT, message: "must be MM:SS" }
  validates :analysis_end, presence: true, format: { with: TIME_CODE_FORMAT, message: "must be MM:SS" }
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
    return nil unless parts.length == 2
    mm = Integer(parts[0], 10)
    ss = Integer(parts[1], 10)
    return nil unless mm >= 0 && ss.between?(0, 59)

    (mm * 60) + ss
  rescue ArgumentError, TypeError
    nil
  end
end
