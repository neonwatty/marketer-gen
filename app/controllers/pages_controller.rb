class PagesController < ApplicationController
  allow_unauthenticated_access only: [:help]
  
  def help
    # Help page - accessible to all users
  end
end