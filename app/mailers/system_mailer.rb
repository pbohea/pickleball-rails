class SystemMailer < ApplicationMailer
  def ping(to:)
    mail(to:, subject: "Pickleball mail test", body: "If you got this, SMTP via SES works 🎉")
  end
end
