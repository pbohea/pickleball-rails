# app/mailers/feedback_mailer.rb
class FeedbackMailer < ApplicationMailer
  def feedback_submission(feedback_params, submitter_email, submitter_type)
    @message = feedback_params[:message]
    @categories = feedback_params[:categories] || []
    @submitter_email = submitter_email
    @submitter_type = submitter_type
    @timestamp = Time.current

    mail(
      from: "admin@pickleball.co",
      to: "admin@pickleball.co",
      subject: "New Feedback Submission - #{@categories.join(', ').presence || 'No Category'}"
    )
  end
end
