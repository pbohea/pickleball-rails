class PopulateSlugs < ActiveRecord::Migration[8.0]
  def up
    # Populate artist slugs
    Artist.find_each do |artist|
      next if artist.slug.present?
      artist.save! # This will trigger the generate_slug callback
    end

    # Populate venue slugs  
    Venue.find_each do |venue|
      next if venue.slug.present?
      venue.save! # This will trigger the generate_slug callback
    end
  end

  def down
    Artist.update_all(slug: nil)
    Venue.update_all(slug: nil)
  end
end