# == Schema Information
#
# Table name: venues
#
#  id             :bigint           not null, primary key
#  category       :string
#  city           :string
#  events_count   :integer
#  latitude       :float
#  longitude      :float
#  name           :string
#  scrapable      :boolean          default(FALSE), not null
#  slug           :string
#  state          :string
#  street_address :string
#  time_zone      :string
#  website        :string
#  zip_code       :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  owner_id       :integer
#  place_id       :string
#
# Indexes
#
#  index_venues_on_place_id  (place_id)
#  index_venues_on_slug      (slug) UNIQUE
#
class Venue < ApplicationRecord
  attr_accessor :skip_geocoding

  belongs_to :owner, optional: true
  has_many :events
  has_many :venue_follows, dependent: :destroy

  has_one_attached :image

  scope :owned, -> { where.not(owner_id: nil) }
  scope :unowned, -> { where(owner_id: nil) }

  geocoded_by :full_address, latitude: :latitude, longitude: :longitude

  before_validation :normalize_website_url
  before_validation :generate_slug

  validates :name, :street_address, :city, :state, :zip_code, presence: true
  validates :website, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
  validates :place_id, uniqueness: true, allow_nil: true

  # UPDATED: Validate geocoding before saving
  validate :ensure_valid_coordinates, if: :should_geocode?

  before_save :assign_time_zone_from_coords, if: :time_zone_blank_and_coords_present?

  def time_zone_blank_and_coords_present?
    time_zone.blank? && latitude.present? && longitude.present?
  end

  CATEGORIES = [
    "Bar",
    "Bar & Restaurant",
    "Cafe",
    "Jazz Club",
    "Nightclub",
    "Pub",
    "Restaurant",
  ].freeze

  def full_address
    [street_address, city, state, zip_code].compact.join(", ")
  end

  def followers
    VenueFollow.where(venue: self).includes(:follower).map(&:follower)
  end

  def to_param
    slug
  end

  def tz_name
    time_zone.presence || Time.zone.name # fallback to app zone
  end

  private

  def generate_slug
    return if name.blank?

    base_slug = name.downcase.gsub(/[^a-z0-9\-_]/, "-").gsub(/-+/, "-").gsub(/^-+|-+$/, "")
    base_slug = "venue" if base_slug.blank?

    slug_candidate = base_slug
    counter = 1

    while Venue.where(slug: slug_candidate).where.not(id: id).exists?
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = slug_candidate
  end

  def normalize_website_url
    return if website.blank?

    unless website =~ /\Ahttps?:\/\//
      self.website = "https://#{website.strip}"
    end
  end

  def address_changed?
    street_address_changed? || city_changed? || state_changed? || zip_code_changed?
  end

  def should_geocode?
    return false if skip_geocoding
    address_changed? || (new_record? && address_fields_present?)
  end

  def address_fields_present?
    street_address.present? && city.present? && state.present? && zip_code.present?
  end

  # UPDATED: Validation method that prevents saving if geocoding fails
  def ensure_valid_coordinates
    # Store original coordinates in case we need to restore them
    original_lat = latitude_was
    original_lng = longitude_was

    # Try to geocode the new address
    result = Geocoder.search(full_address).first

    if result&.coordinates
      # Geocoding succeeded - update coordinates
      self.latitude = result.latitude
      self.longitude = result.longitude
      Rails.logger.info "Geocoded venue #{name}: #{full_address} -> #{latitude}, #{longitude}"
    else
      # Geocoding failed - restore original coordinates and add error
      self.latitude = original_lat
      self.longitude = original_lng

      errors.add(:base, "Unable to find coordinates for the address '#{full_address}'. Please check that the address is correct and complete.")
      Rails.logger.warn "Geocoding failed for venue #{name}: #{full_address}"
    end
  rescue StandardError => e
    # Handle network errors or API failures
    self.latitude = latitude_was
    self.longitude = longitude_was

    errors.add(:base, "Address validation service is temporarily unavailable. Please try again later.")
    Rails.logger.error "Geocoding error for venue #{name}: #{e.message}"
  end

  def assign_time_zone_from_coords
    return unless latitude.present? && longitude.present?
    tf = self.class.timezone_finder
    tzid = tf.timezone_at(lat: latitude, lng: longitude) || tf.closest_timezone_at(lat: latitude, lng: longitude)
    self.time_zone = tzid if tzid && ActiveSupport::TimeZone[tzid]
  end

  def self.timezone_finder
    @timezone_finder ||= TimezoneFinder.create
  end
end
