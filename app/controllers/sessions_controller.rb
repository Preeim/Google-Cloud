class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by("LOWER(username) = ? OR LOWER(email) = ?", params[:login].to_s.strip.downcase, params[:login].to_s.strip.downcase)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      flash[:notice] = "Welcome back, #{user.username}!"
      redirect_to root_path
    else
      flash.now[:alert] = "Invalid credentials. Please check your username/email and password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    flash[:notice] = "You have been signed out."
    redirect_to root_path
  end
end

