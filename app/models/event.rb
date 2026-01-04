# == Schema Information
#
# Table name: events
#
#  id             :bigint           not null, primary key
#  artist_name    :string
#  category       :string
#  cover          :boolean
#  cover_amount   :integer
#  date           :date
#  description    :string
#  end_time       :datetime
#  import_source  :string
#  indoors        :boolean          default(TRUE)
#  start_time     :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  artist_id      :integer
#  artist_lead_id :bigint
#  promoter_id    :bigint
#  venue_id       :integer
#
# Indexes
#
#  index_events_on_artist_lead_id  (artist_lead_id)
#  index_events_on_import_source   (import_source)
#  index_events_on_promoter_id     (promoter_id)
#
# Foreign Keys
#
#  fk_rails_...  (artist_lead_id => artist_leads.id)
#  fk_rails_...  (promoter_id => promoters.id)
#
class Event < ApplicationRecord
  belongs_to :venue
  belongs_to :artist, optional: true
  belongs_to :artist_lead, optional: true
  belongs_to :promoter, optional: true   

  has_many :event_artists, dependent: :destroy
  has_many :additional_artists, through: :event_artists, source: :artist


  # Set default values
  after_initialize :set_defaults, if: :new_record?
  
  before_save :force_no_cover


  # before_validation :backfill_end_time_if_missing

  before_save :normalize_times_in_venue_zone
  before_save :set_artist_name_from_artist

 

  scope :recently_posted, ->(hours = 24) {
    where('events.created_at >= ?', hours.hours.ago)
  }

  scope :upcoming, -> {
    where("end_time > ?", Time.current)
      .order(:start_time)
  }

  scope :past, -> {
    where("end_time < ?", Time.current)
      .order(start_time: :desc)
  }
  scope :today, -> { where("DATE(start_time) = ?", Date.today) }
  scope :next_7_days, -> { where(start_time: Time.current..7.days.from_now) }

  validate :artist_presence
    def artist_presence
      has_primary   = artist_id.present? || artist_name.present?
      has_additional = event_artists.any?
      unless has_primary || has_additional
        errors.add(:base, "Please select at least one artist (or enter a name).")
      end
    end
  validate :no_time_conflicts, on: [:create, :update]

  validates :category, presence: true, inclusion: { in: Artist::PERFORMANCE_TYPES },
            unless: :imported_from_web?

  def imported_from_web?
    import_source == "web"
  end

  # -------------------------
  # Helpers for rendering
  # -------------------------
  def starts_at_local
    start_time.in_time_zone(venue_tz)
  end

  def ends_at_local
    end_time.in_time_zone(venue_tz)
  end

  def past?
    end_time.present? ? end_time < Time.current : false
  end

  # Helper method to check if event is outdoors
  def outdoors?
    !indoors?
  end

  def all_artists # AR collection of DB artists (primary + additional)
    ids = [artist_id].compact + event_artists.where.not(artist_id: nil).pluck(:artist_id)
    Artist.where(id: ids)
  end

  def all_artist_names # Array of strings (DB usernames + manual)
    names = []
    names << artist.username if artist.present?
    names += event_artists.ordered.includes(:artist).map { |ea| ea.display_name }.compact
    names.uniq
  end

  private

  def force_no_cover
    self.cover = false
    self.cover_amount = nil
  end

  def no_time_conflicts
    return unless venue_id.present? && date.present?

    zone = ActiveSupport::TimeZone[venue_tz]

    # Pull raw inputs if present (form may pass strings); otherwise use datetimes
    raw_start = try(:start_time_before_type_cast).presence || start_time
    raw_end   = try(:end_time_before_type_cast).presence   || end_time

    return unless raw_start.present? # need at least a start

    sh, sm = parse_time_input(raw_start)
    start_local = zone.local(date.year, date.month, date.day, sh, sm)

    end_local =
      if raw_end.present?
        eh, em = parse_time_input(raw_end)
        tmp = zone.local(date.year, date.month, date.day, eh, em)
        tmp += 1.day if tmp <= start_local # overnight
        tmp
      else
        start_local + 2.hours
      end

    s = start_local.utc
    e = end_local.utc

    # Strict overlap: allow adjacent
    rel = Event.where(venue_id: venue_id).where.not(id: id)
               .where("NOT (end_time <= ? OR start_time >= ?)", s, e)

    if rel.exists?
      errors.add(:base, "There is already an event scheduled at this time at this venue.")
    end
  end

  def set_defaults
    self.indoors = true if indoors.nil?
    self.cover = false if cover.nil?
    self.cover_amount = nil if cover == false
  end

  def normalize_times_in_venue_zone
    return unless date.present? && start_time.present?

    zone = ActiveSupport::TimeZone[venue_tz]

    raw_start = try(:start_time_before_type_cast)
    raw_end   = try(:end_time_before_type_cast)

    sh, sm = parse_time_input(raw_start.presence || start_time)
    start_local = zone.local(date.year, date.month, date.day, sh, sm)

    if raw_end.present? || end_time.present?
      eh, em = parse_time_input(raw_end.presence || end_time)
      end_local = zone.local(date.year, date.month, date.day, eh, em)
      end_local += 1.day if end_local <= start_local
    else
      # default to 3 hours if no end time was supplied
      end_local = start_local + 3.hours
    end

    self.start_time = start_local
    self.end_time   = end_local
  end

  def parse_time_input(input)
    case input
    when String
      parts = input.split(":").map(&:to_i)
      [parts[0] || 0, parts[1] || 0]
    else
      [input.hour, input.min]
    end
  end

  def venue_tz
    venue&.tz_name || Time.zone.name
  end

  def set_artist_name_from_artist
    if artist_id.present? && artist.present?
      self.artist_name = artist.username
    end
  end

  def artist_presence
    if artist_id.blank? && artist_name.blank?
      errors.add(:base, "Please select an artist or enter a name.")
    end
  end

  # def backfill_end_time_if_missing
  #   return unless start_time.present?
  #   self.end_time ||= start_time + 3.hours
  # end
end
