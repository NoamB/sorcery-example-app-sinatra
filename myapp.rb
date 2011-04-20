require 'sinatra'
enable :sessions

require 'sqlite3'
require 'active_record'
require 'logger'
# establish connection
ActiveRecord::Base.establish_connection(
  :adapter  => "sqlite3",
  :database => "dummy",
  :verbosity => "quiet"
)
ActiveRecord::Base.logger = Logger.new(STDOUT)

# mailer
require 'action_mailer'
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.smtp_settings = {
  :address              => "smtp.gmail.com",
  :port                 => 587,
  :domain               => 'example.com',
  :user_name            => 'nbenari',# put your real username here to send emails.
  :password             => 'secret', # put your real password here to send emails.
  :authentication       => 'plain',
  :enable_starttls_auto => true  
}

ActionMailer::Base.view_paths = File.join(File.dirname(__FILE__), 'views')

require File.join(File.dirname(__FILE__),'models','sorcery_mailer')

# sorcery
require 'sorcery'
require_relative 'sorcery_config'

# models
require File.join(File.dirname(__FILE__),'models','authentication')
require File.join(File.dirname(__FILE__),'models','user')

# filters
['/logout'].each do |patt|
  before patt do
    require_login
  end
end

before '/login/http' do
  require_login_from_http_basic
end

before do
  @notice = session[:notice]
  @alert = session[:alert]
  session[:notice] = nil
  session[:alert] = nil
end

# helpers
helpers do
  def current_users_list
    current_users.map {|u| u.email}.join(", ")
  end
  
  def not_authenticated
    halt "You must login to see this page!"
  end
end

# actions
get '/' do
  @users = User.all
  erb :'users/index'
end

# registration
get '/users/new' do
  @user = User.new
  erb :'users/new'
end

post '/users' do
  @user = User.new(params[:user])
  if @user.save
    session[:notice] = "Success!"
    redirect '/'
  else
    session[:alert] = "Failed!"
    redirect '/'
  end
end

get '/users/:id/activate' do
  if @user = User.load_from_activation_token(params[:id])
    @user.activate!
    session[:notice] = 'User was successfully activated.'
    redirect '/login'
  else
    not_authenticated
  end
end

# login/logout
get '/login' do
  erb :'user_sessions/new'
end

get '/logout' do
  logout
  session[:notice] = "Logged out!"
  redirect '/'
end

post '/login' do
  @user = login(params[:email],params[:password],params[:remember])
  if @user
    session[:notice] = "Login Success!"
  else
    session[:alert] = "Login Failed!"
  end
  redirect '/'
end

# password reset
post '/password_resets' do
  @user = User.find_by_email(params[:email])
  
  # This line sends an email to the user with instructions on how to reset their password (a url with a random token)
  @user.deliver_reset_password_instructions! if @user
  
  # Tell the user instructions have been sent whether or not email was found.
  # This is to not leak information to attackers about which emails exist in the system.
  session[:notice] = 'Instructions have been sent to your email.'
  redirect '/'
end

get '/password_resets/:token/edit' do
  @user = User.load_from_reset_password_token(params[:token])
  @token = params[:token]
  not_authenticated if !@user
  erb :'password_resets/edit'
end

put '/password_resets/:id' do
  @user = User.load_from_reset_password_token(params[:token])
  not_authenticated if !@user
  # the next line clears the temporary token and updates the password
  if @user.reset_password!(params[:user])
    session[:notice] = 'Password was successfully updated.'
    redirect '/'
  else
    erb :'password_resets/edit'
  end
end

# HTTP Basic Auth
get '/login/http' do
  erb "HTTP Basic Auth"
end

# External
get '/auth_at_provider' do
  login_at(params[:provider])
end

get '/oauth/callback' do
  provider = params[:provider]
  @user = login_from(provider)
  if @user
    session[:notice] = "Success!"
    redirect '/'
  else
    if @user = create_from(provider)
      @user.activate!
      session.clear # protect from session fixation attack
      login_user(@user)
      session[:notice] = "User created!"
      redirect '/'
    else
      session[:alert] = "Failed!"
      redirect '/'
    end
  end
end
