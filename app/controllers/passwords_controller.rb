class PasswordsController < ApplicationController

  def new
    @password = Password.new

    # Commented out for now to be more like bort,
    # althought it would be cool to be so restful
    # that we even allow restful password updating.
    #
    # respond_to do |format|
    #   format.html # new.html.erb
    #   format.xml  { render :xml => @password }
    # end
  end

  def create
    @password = Password.new(params[:password])
    @password.user = User.find_by_email(@password.email)
    
    # respond_to do |format|
    #   if @password.save
    #     PasswordMailer.deliver_forgot_password(@password)
    #     flash[:notice] = "A link to change your password has been sent to #{@password.email}."
    #     format.html { redirect_to(:action => 'new') }
    #     format.xml  { render :xml => @password, :status => :created, :location => @password }
    #   else
    #     format.html { render :action => "new" }
    #     format.xml  { render :xml => @password.errors, :status => :unprocessable_entity }
    #   end
    # end
    
    if @password.save
      PasswordMailer.deliver_forgot_password(@password)
      flash[:notice] = "A link to change your password has been sent to #{@password.email}."
      redirect_to :action => :new
    else
      render :action => :new
    end
  end

  def reset
    begin
      @user = Password.find(:first, :conditions => ['reset_code = ? and expiration_date > ?', params[:reset_code], Time.now]).user
    rescue
      flash[:notice] = 'The change password URL you visited is either invalid or expired.'
      redirect_to(new_password_path)
    end    
  end

  def update_after_forgetting
    @user = Password.find_by_reset_code(params[:reset_code]).user
    
    # respond_to do |format|
    #   if @user.update_attributes(params[:user])
    #     flash[:notice] = 'Password was successfully updated.'
    #     format.html { redirect_to(:action => :reset, :reset_code => params[:reset_code]) }
    #   else
    #     flash[:notice] = 'EPIC FAIL!'
    #     format.html { redirect_to(:action => :reset, :reset_code => params[:reset_code]) }
    #   end
    # end
    
    if @user.update_attributes(params[:user])
      flash[:notice] = 'Your password was successfully updated. You can login now with it if you like.'
      redirect_to login_path
    else
      flash[:notice] = 'Something went wrong updating your password!'
      redirect_to :action => :reset, :reset_code => params[:reset_code]
    end
  end
  
  def update
    @password = Password.find(params[:id])

    # respond_to do |format|
    #   if @password.update_attributes(params[:password])
    #     flash[:notice] = 'Password was successfully updated.'
    #     format.html { redirect_to(@password) }
    #     format.xml  { head :ok }
    #   else
    #     format.html { render :action => "edit" }
    #     format.xml  { render :xml => @password.errors, :status => :unprocessable_entity }
    #   end
    # end
    
    if @password.update_attributes(params[:password])
      flash[:notice] = 'Your password was successfully updated.'
      redirect_to(@password)
    else
      render :action => :edit
    end
  end

end
