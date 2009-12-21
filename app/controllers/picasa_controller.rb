class PicasaController < ApplicationController
  before_filter :login_required
  verify :method => :delete, :only => "unlink"
  
  # Configure Picasa linkage
  def options
    if @picasa_identity = current_user.picasa_identity
      @picasa = Picasa.new(@picasa_identity.token)
      @picasa_photos = @picasa.recent_photos(@picasa_identity.picasa_user_id).entries
    else
      @auth_url = Picasa.authorization_url(url_for(:action => "authorize"))
    end
  end
  
  # Receives redirect from Google after initial auth
  def authorize
    begin
      @picasa = Picasa.authorize_request(self.request)
    rescue RubyPicasa::PicasaTokenError
      flash[:error] = "Picasa authorization failed!"
      return redirect_to :action => "link"
    end
    
    @picasa_identity = PicasaIdentity.find_or_create_by_user_id(current_user.id)
    @picasa_identity.token = @picasa.token
    @picasa_user = @picasa.user('default')
    @picasa_identity.picasa_user_id = @picasa_user.user
    @picasa_identity.save
    
    flash[:notice] = "Congrats, your iNaturalist and Picasa accunts have been linked!"
    redirect_to :action => "options"
  end
  
  # Offer user option to unlink iNat & Picasa accounts
  def unlink
    if current_user.picasa_identity
      current_user.picasa_identity.destroy
      flash[:notice] = "We've dissassociated your Picasa account from your iNaturalist account."
      redirect_to :action => 'options'
    else
      flash[:notice] = "Your Picasa account has not been linked before!"
      redirect_to :action => 'options'
    end
  end
end