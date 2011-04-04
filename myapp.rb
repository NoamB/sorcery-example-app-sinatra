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

# models
require 'sorcery'
Sorcery::Controller::Config.submodules = [:user_activation, :http_basic_auth, :remember_me, :reset_password, :session_timeout, :brute_force_protection, :activity_logging, :oauth]
include Sorcery::Controller::Adapters::Sinatra
include Sorcery::Controller

Sinatra::Application.activate_sorcery! do |config|
  config.session_timeout = 10.minutes
  config.session_timeout_from_last_action = false

  config.controller_to_realm_map = {"application" => "Application", "users" => "Users"}

  config.oauth_providers = [:twitter, :facebook]

  config.twitter.key = "eYVNBjBDi33aa9GkA3w"
  config.twitter.secret = "XpbeSdCoaKSmQGSeokz5qcUATClRW5u08QWNfv71N8"
  config.twitter.callback_url = "http://0.0.0.0:3000/oauth/callback?provider=twitter"
  config.twitter.user_info_mapping = {:email => "screen_name"}

  config.facebook.key = "34cebc81c08a521bc66e212f947d73ec"
  config.facebook.secret = "5b458d179f61d4f036ee66a497ffbcd0"
  config.facebook.callback_url = "http://0.0.0.0:3000/oauth/callback?provider=facebook"
  config.facebook.user_info_mapping = {:email => "name"}
end
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

# OAuth
get '/auth_at_provider' do
  auth_at_provider(params[:provider])
end

get '/oauth/callback' do
  provider = params[:provider]
  @user = login_from_access_token(provider)
  if @user
    session[:notice] = "Success!"
    redirect '/'
  else
    if @user = create_from_provider!(provider)
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
