# == Schema Information
#
# Table name: owners
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  unconfirmed_email      :string
#  venuescount            :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_owners_on_confirmation_token    (confirmation_token) UNIQUE
#  index_owners_on_email                 (email) UNIQUE
#  index_owners_on_reset_password_token  (reset_password_token) UNIQUE
#
class Owner < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  include UniqueEmailAcrossModels
  
  validate :password_complexity

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  has_many :venues, dependent: :nullify
  has_many :events, through: :venues
  has_many :notification_tokens, dependent: :destroy
  has_many :artist_follows, as: :follower, dependent: :destroy
  has_many :followed_artists, through: :artist_follows, source: :artist
  has_many :venue_follows, as: :follower, dependent: :destroy
  has_many :followed_venues, through: :venue_follows, source: :venue

  def upcoming_events
    events.upcoming
  end

  def past_events
    events.past
  end

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
