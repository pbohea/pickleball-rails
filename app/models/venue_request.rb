# == Schema Information
#
# Table name: venue_requests
#
#  id                :bigint           not null, primary key
#  category          :string           not null
#  city              :string           not null
#  name              :string           not null
#  notes             :text
#  owner_phone       :string
#  ownership_claim   :boolean          default(FALSE), not null
#  request_type      :string
#  requester_type    :string           not null
#  state             :string(2)        not null
#  status            :integer          default("pending"), not null
#  street_address    :string           not null
#  website           :string
#  zip_code          :string(10)       not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  existing_venue_id :integer
#  requester_id      :integer          not null
#  venue_id          :integer
#
# Indexes
#
#  index_venue_requests_on_ownership_claim                  (ownership_claim)
#  index_venue_requests_on_requester_type_and_requester_id  (requester_type,requester_id)
#  index_venue_requests_on_status                           (status)
#  index_venue_requests_on_venue_id                         (venue_id)
#
class VenueRequest < ApplicationRecord
  belongs_to :venue, optional: true
  has_one_attached :utility_bill

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :street_address, presence: true, length: { minimum: 5, maximum: 200 }
  validates :city, presence: true, length: { minimum: 2, maximum: 50 }
  validates :state, presence: true, inclusion: {
                      in: %w[AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY],
                    }
  validates :zip_code, presence: true, format: { with: /\A\d{5}(-\d{4})?\z/ }
  validates :category, presence: true, inclusion: {
                         in: Venue::CATEGORIES,
                       }
  validates :requester_type, presence: true, inclusion: { in: %w[artist owner promoter] }
  validates :requester_id, presence: true, numericality: { greater_than: 0 }

  validates :request_type, presence: true, inclusion: { in: %w[new_venue existing_venue_claim] }
  validates :existing_venue_id, presence: true, if: :existing_venue_claim?

  # Owner-specific validations
  # validates :owner_phone, presence: true, if: :ownership_claim?
  validates :utility_bill, presence: true, if: :ownership_claim?

  # Rails 8 enum syntax
  enum :status, { pending: 0, approved: 1, rejected: 2, duplicate: 3 }

  def ownership_claim?
    ownership_claim == true
  end

  def existing_venue_claim?
    request_type == "existing_venue_claim"
  end

  def new_venue_request?
    request_type == "new_venue"
  end

  def existing_venue
    Venue.find_by(id: existing_venue_id) if existing_venue_claim?
  end

  def full_address
    "#{street_address}, #{city}, #{state} #{zip_code}"
  end

  def requester
    case requester_type
    when "artist"
      Artist.find_by(id: requester_id)
    when "owner"
      Owner.find_by(id: requester_id)
    when "promoter"
      Promoter.find_by(id: requester_id)
    end
  end

  def approve_and_create_venue!
    return false unless pending?

    begin
      ActiveRecord::Base.transaction do
        if existing_venue_claim?
          # Just assign ownership to existing venue
          venue = existing_venue
          venue.update!(owner_id: requester_id)

          # Skip validation when updating status since we're just changing administrative fields
          update_columns(
            status: VenueRequest.statuses[:approved],
            venue_id: venue.id,
            updated_at: Time.current,
          )
          venue
        else
          # Create new venue (existing logic)
          venue = Venue.create!(
            name: name,
            street_address: street_address,
            city: city,
            state: state,
            zip_code: zip_code,
            website: website,
            category: category,
          )

          venue.skip_geocoding = true

          if ownership_claim? && requester_type == "owner"
            venue.update!(owner_id: requester_id)
          end

          # venue.geocode if venue.respond_to?(:geocode)

          # Skip validation for status update
          update_columns(
            status: VenueRequest.statuses[:approved],
            venue_id: venue.id,
            updated_at: Time.current,
          )
          venue
        end
      end
    rescue => e
      Rails.logger.error "Failed to approve venue request #{id}: #{e.message}"
      false
    end
  end
end
