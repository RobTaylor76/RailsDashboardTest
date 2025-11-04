class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]
  
  def new
    redirect_to dashboard_path if logged_in?
  end

  def create
    user = User.find_by(username: params[:username])
    
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: 'Successfully logged in!'
    else
      flash.now[:alert] = 'Invalid username or password'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: 'Successfully logged out!'
  end
end
