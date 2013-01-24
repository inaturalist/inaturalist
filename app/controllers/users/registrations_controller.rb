class Users::RegistrationsController < Devise::RegistrationsController
  def create
    build_resource

    if resource.save
      if resource.active_for_authentication?
        set_flash_message :notice, :signed_up if is_navigational_format?
        sign_in(resource_name, resource)
        if session[:return_to_for_new_user]
          redirect_to session[:return_to_for_new_user]
        else
          redirect_to home_path
        end
        return
      else
        set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_navigational_format?
        expire_session_data_after_sign_in!
        redirect_to root_url
        return
      end
    else
      clean_up_passwords resource
      respond_with(resource) do |format|
        format.html { render :new }
        format.mobile { render :new, :status => 422 }
      end
    end
  end
end
