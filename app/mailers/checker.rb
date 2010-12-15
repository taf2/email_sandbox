# Send a test email from the email server to the smtp server to ensure it's working properly
class Checker < ActionMailer::Base
  default :from => "info@captico.com"

  def check_smtp
    mail :to => 'test@captico.com', :subject => 'Test Email', :body => 'hello there world'
  end

end
