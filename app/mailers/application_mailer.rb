class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('GMAIL_USERNAME', 'noreply@mynovel.com')
  layout 'mailer'
end