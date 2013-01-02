class HelpController < ApplicationController
  def index
    redirect_to INAT_CONFIG['help_url']
  end
  
  def getting_started
    redirect_to "/pages/getting+started"
  end

end
