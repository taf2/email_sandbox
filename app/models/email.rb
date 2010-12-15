class Email < ActiveRecord::Base
  validates :to, :presence => true
  validates :from, :presence => true
  validates :message, :presence => true

  def subject
    message.scan(/^Subject: (.*)\r\n/).flatten.first
  end

  def to_email
    to.strip.sub(/^</,'').sub(/>$/,'') 
  end

  def from_email
    from.strip.sub(/^</,'').sub(/>$/,'') 
  end
end
