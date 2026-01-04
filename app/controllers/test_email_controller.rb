class TestEmailController < ApplicationController
  def send_ping
    to = params.fetch(:to)
    SystemMailer.ping(to: to).deliver_now
    render plain: "Sent ping to #{to}"
  end
end
