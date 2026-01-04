# == Schema Information
#
# Table name: promoters
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string
#  organization           :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_promoters_on_confirmation_token    (confirmation_token) UNIQUE
#  index_promoters_on_email                 (email) UNIQUE
#  index_promoters_on_reset_password_token  (reset_password_token) UNIQUE
#
# app/models/promoter.rb
class Promoter < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  include UniqueEmailAcrossModels
  validate :password_complexity

  # Follows (polymorphic)
  has_many :artist_follows, as: :follower, dependent: :destroy
  has_many :venue_follows,  as: :follower, dependent: :destroy

  # Expose with short names:
  has_many :artists, through: :artist_follows, source: :artist
  has_many :venues,  through: :venue_follows,  source: :venue

  # (optional) keep the explicit “followed_*” names too, if used elsewhere
  has_many :followed_artists, through: :artist_follows, source: :artist
  has_many :followed_venues,  through: :venue_follows,  source: :venue

  has_many :events, dependent: :nullify

  def password_complexity
    return if password.blank?
    unless password.length.between?(8, 20)
      errors.add :password, "must be between 8 and 20 characters"
    end
    unless password.match?(/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
      errors.add :password, "must include at least one lowercase letter, one uppercase letter, and one number"
    end
  end
end
