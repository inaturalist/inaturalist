class <%= controller_class_name %>Controller < ApplicationController

  def new
    @<%= file_name %> = <%= class_name %>.new
    
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @<%= file_name %> }
    end
  end

  def create
    @<%= file_name %> = <%= class_name %>.new(params[:<%= file_name %>])
    @<%= file_name %>.<%= user_model_name %> = <%= user_model_name.capitalize %>.find_by_email(@<%= file_name %>.email)
    
    respond_to do |format|
      if @<%= file_name %>.save
        <%= class_name %>Mailer.deliver_forgot_password(@<%= file_name %>)
        flash[:notice] = "A link to change your password has been sent to #{@<%= file_name %>.email}."
        format.html { redirect_to(:action => 'new') }
        format.xml  { render :xml => @<%= file_name %>, :status => :created, :location => @<%= file_name %> }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @<%= file_name %>.errors, :status => :unprocessable_entity }
      end
    end
  end

  def reset
    begin
      @<%= user_model_name %> = <%= class_name %>.find(:first, :conditions => ['reset_code = ? and expiration_date > ?', params[:reset_code], Time.now]).<%= user_model_name %>
    rescue
      flash[:notice] = 'The change password URL you visited is either invalid or expired.'
      redirect_to(new_<%= file_name %>_path)
    end    
  end

  def update_after_forgetting
    @<%= user_model_name %> = <%= class_name %>.find_by_reset_code(params[:reset_code]).<%= user_model_name %>
    
    respond_to do |format|
      if @<%= user_model_name %>.update_attributes(params[:<%= user_model_name %>])
        flash[:notice] = 'Password was successfully updated.'
        format.html { redirect_to(:action => :reset, :reset_code => params[:reset_code]) }
      else
        flash[:notice] = 'EPIC FAIL!'
        format.html { redirect_to(:action => :reset, :reset_code => params[:reset_code]) }
      end
    end
  end
  
  def update
    @<%= file_name %> = <%= class_name %>.find(params[:id])

    respond_to do |format|
      if @<%= file_name %>.update_attributes(params[:<%= file_name %>])
        flash[:notice] = 'Password was successfully updated.'
        format.html { redirect_to(@<%= file_name %>) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @<%= file_name %>.errors, :status => :unprocessable_entity }
      end
    end
  end

end
