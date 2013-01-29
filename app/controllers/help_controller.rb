class HelpController < ApplicationController
  def index
    redirect_to CONFIG.get(:help_url)
  end
  
  def getting_started
    redirect_to "/pages/getting+started"
  end

end
