# app/models/concerns/unique_email_across_models.rb
module UniqueEmailAcrossModels
  extend ActiveSupport::Concern

  included do
    validate :email_unique_across_all_models, on: :create
    validate :email_unique_across_all_models_on_update, on: :update
  end

  private

  def email_unique_across_all_models
    return if email.blank?

    existing_models = check_email_exists_in_other_models
    
    if existing_models.any?
      errors.add(:email, "is already registered as #{existing_models.to_sentence}")
    end
  end

  def email_unique_across_all_models_on_update
    return if email.blank? || !email_changed?

    existing_models = check_email_exists_in_other_models(exclude_current: true)
    
    if existing_models.any?
      errors.add(:email, "is already registered as #{existing_models.to_sentence}")
    end
  end

  def check_email_exists_in_other_models(exclude_current: false)
    existing_models = []
    
    # Check User model
    user_query = User.where(email: email)
    user_query = user_query.where.not(id: id) if exclude_current && is_a?(User)
    existing_models << "User" if user_query.exists? && !is_a?(User)
    
    # Check Owner model  
    owner_query = Owner.where(email: email)
    owner_query = owner_query.where.not(id: id) if exclude_current && is_a?(Owner)
    existing_models << "Owner" if owner_query.exists? && !is_a?(Owner)
    
    # Check Artist model
    artist_query = Artist.where(email: email)  
    artist_query = artist_query.where.not(id: id) if exclude_current && is_a?(Artist)
    existing_models << "Artist" if artist_query.exists? && !is_a?(Artist)

    # For updates, also check if current model type has conflicts with other types
    if exclude_current
      if is_a?(User) && (Owner.where(email: email).exists? || Artist.where(email: email).exists?)
        existing_models << "Owner" if Owner.where(email: email).exists?
        existing_models << "Artist" if Artist.where(email: email).exists?
      elsif is_a?(Owner) && (User.where(email: email).exists? || Artist.where(email: email).exists?)
        existing_models << "User" if User.where(email: email).exists?
        existing_models << "Artist" if Artist.where(email: email).exists?
      elsif is_a?(Artist) && (User.where(email: email).exists? || Owner.where(email: email).exists?)
        existing_models << "User" if User.where(email: email).exists?
        existing_models << "Owner" if Owner.where(email: email).exists?
      end
    end

    existing_models.uniq
  end
end
