# == Schema Information
#
# Table name: artists
#
#  id                     :bigint           not null, primary key
#  bio                    :text
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  genre                  :string
#  image                  :string
#  instagram_username     :string
#  performance_type       :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  slug                   :string
#  tiktok_username        :string
#  unconfirmed_email      :string
#  username               :string
#  website                :string
#  youtube_username       :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  spotify_artist_id      :string
#
# Indexes
#
#  index_artists_on_confirmation_token    (confirmation_token) UNIQUE
#  index_artists_on_email                 (email) UNIQUE
#  index_artists_on_instagram_username    (instagram_username)
#  index_artists_on_reset_password_token  (reset_password_token) UNIQUE
#  index_artists_on_slug                  (slug) UNIQUE
#  index_artists_on_spotify_artist_id     (spotify_artist_id)
#  index_artists_on_tiktok_username       (tiktok_username)
#  index_artists_on_youtube_username      (youtube_username)
#
class Artist < ApplicationRecord
  require "net/http"
  require "uri"
  include UniqueEmailAcrossModels
  # Devise
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # ------------------------------------
  # Associations
  # ------------------------------------
  has_many :events, foreign_key: "artist_id"
  has_many :venues, through: :events

  # Followers of THIS artist (Users/Owners/Artists can follow an Artist)
  has_many :artist_follows, dependent: :destroy

  # When THIS artist follows others (polymorphic follower)
  has_many :artist_followings, as: :follower, class_name: "ArtistFollow", dependent: :destroy
  has_many :followed_artists, through: :artist_followings, source: :artist

  has_many :venue_follows, as: :follower, dependent: :destroy
  has_many :followed_venues, through: :venue_follows, source: :venue

  has_many :artist_leads, dependent: :nullify

  has_one_attached :image
  has_many :notification_tokens, dependent: :destroy

  has_many :event_artists, dependent: :destroy
  has_many :events_as_additional, through: :event_artists, source: :event

  # ------------------------------------
  # Constants
  # ------------------------------------
  GENRES = %w[Country Rock Alternative Jazz Electronic Hip-Hop Pop Folk Other].freeze
  PERFORMANCE_TYPES = %w[Guitar Piano Band DJ Other].freeze

  # ------------------------------------
  # Validations
  # ------------------------------------
  validates :bio, length: { maximum: 140, message: "must be 140 characters or less" }
  validate :website_https_supported, if: -> { website.present? }
  validate :social_usernames_format

  # ------------------------------------
  # Callbacks
  # ------------------------------------
  before_validation :normalize_social_usernames
  before_validation :generate_slug

  # ------------------------------------
  # Virtual attributes for full URLs
  # ------------------------------------
  def instagram_url
    return nil if instagram_username.blank?
    "https://instagram.com/#{instagram_username}"
  end

  def youtube_url
    return nil if youtube_username.blank?
    "https://youtube.com/@#{youtube_username}"
  end

  def tiktok_url
    return nil if tiktok_username.blank?
    "https://tiktok.com/@#{tiktok_username}"
  end

  def spotify_url
    return nil if spotify_artist_id.blank?
    "https://open.spotify.com/artist/#{spotify_artist_id}"
  end

  # ------------------------------------
  # Instance Methods
  # ------------------------------------
  def upcoming_events
    # instant-based + eager-load venue for TZ label in views
    events.upcoming.includes(:venue).order(:start_time)
  end

  def past_events
    events.past.includes(:venue).order(start_time: :desc)
  end

  def upcoming_events_including_guest
    Event
      .left_joins(:event_artists)
      .where("events.artist_id = :aid OR event_artists.artist_id = :aid", aid: id)
      .upcoming
      .includes(:venue)     # eager load to keep your views fast
      .distinct
      .order(:start_time)
  end

  def past_events_including_guest
    Event
      .left_joins(:event_artists)
      .where("events.artist_id = :aid OR event_artists.artist_id = :aid", aid: id)
      .past
      .includes(:venue)
      .distinct
      .order(start_time: :desc)
  end

  def followers
    ArtistFollow.where(artist: self).includes(:follower).map(&:follower)
  end

  def to_param
    slug
  end

  private

  def generate_slug
    return if username.blank?

    base_slug = username.downcase.gsub(/[^a-z0-9\-_]/, "-").gsub(/-+/, "-").gsub(/^-+|-+$/, "")
    base_slug = "artist" if base_slug.blank?

    slug_candidate = base_slug
    counter = 1
    while Artist.where(slug: slug_candidate).where.not(id: id).exists?
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end
    self.slug = slug_candidate
  end

  def password_complexity
    return if password.blank?
  end

  def website_https_supported
    uri = normalize_url(website)
    if uri
      if https_works?(uri)
        self.website = uri.to_s
      else
        errors.add(:website, "must support HTTPS (https://...)")
      end
    else
      errors.add(:website, "is not a valid URL")
    end
  end

  def normalize_url(url)
    uri = URI.parse(url)
    uri = URI.parse("https://#{url}") unless uri.scheme
    uri
  rescue URI::InvalidURIError
    nil
  end

  def https_works?(uri)
    uri.scheme = "https"
    uri.port = 443
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 2) do |http|
      http.head(uri.path.empty? ? "/" : uri.path)
    end
    response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
  rescue StandardError => e
    Rails.logger.warn("HTTPS check failed for #{uri}: #{e.message}")
    false
  end

  def normalize_social_usernames
    # Clean up usernames by removing spaces and converting to lowercase
    %i[instagram_username youtube_username tiktok_username].each do |attr|
      username = self[attr]
      next if username.blank?
      
      # Remove @ symbol if present and clean up
      cleaned = username.strip.downcase.gsub(/^@/, '')
      self[attr] = cleaned
    end

    # Clean up Spotify artist ID
    if spotify_artist_id.present?
      # Remove any URL parts if user pasted a full URL
      cleaned_id = spotify_artist_id.strip
      if cleaned_id.include?('open.spotify.com/artist/')
        cleaned_id = cleaned_id.split('open.spotify.com/artist/').last.split('?').first
      end
      self.spotify_artist_id = cleaned_id
    end
  end

  def social_usernames_format
    # Validate Instagram username
    if instagram_username.present?
      unless instagram_username.match?(/\A[a-zA-Z0-9._]+\z/)
        errors.add(:instagram_username, "can only contain letters, numbers, periods, and underscores")
      end
      if instagram_username.length > 30
        errors.add(:instagram_username, "must be 30 characters or less")
      end
    end

    # Validate YouTube username
    if youtube_username.present?
      unless youtube_username.match?(/\A[a-zA-Z0-9._-]+\z/)
        errors.add(:youtube_username, "can only contain letters, numbers, periods, underscores, and hyphens")
      end
      if youtube_username.length > 30
        errors.add(:youtube_username, "must be 30 characters or less")
      end
    end

    # Validate TikTok username
    if tiktok_username.present?
      unless tiktok_username.match?(/\A[a-zA-Z0-9._]+\z/)
        errors.add(:tiktok_username, "can only contain letters, numbers, periods, and underscores")
      end
      if tiktok_username.length > 24
        errors.add(:tiktok_username, "must be 24 characters or less")
      end
    end

    # Validate Spotify artist ID
    if spotify_artist_id.present?
      unless spotify_artist_id.match?(/\A[a-zA-Z0-9]{22}\z/)
        errors.add(:spotify_artist_id, "must be a valid 22-character Spotify artist ID")
      end
    end
  end
end
