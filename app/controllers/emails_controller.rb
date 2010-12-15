class EmailsController < ApplicationController
  def index
    @emails = Email.order("created_at desc")
  end

  def show
    @email = Email.find(params[:id])
  end

  def check
    Checker.check_smtp.deliver 
    redirect_to emails_path
  end

end
