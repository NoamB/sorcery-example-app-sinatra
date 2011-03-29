require 'sinatra'
enable :sessions

require 'sqlite3'
require 'active_record'

# establish connection
ActiveRecord::Base.establish_connection(
  :adapter  => "sqlite3",
  :database => "dummy",
  :verbosity => "quiet"
)

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

before '/test_http_basic_auth' do
  require_login_from_http_basic
end

before do
  @notice = session[:notice]
  @alert = session[:alert]
  session[:notice] = nil
  session[:alert] = nil
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
  erb :'users/index'
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



def not_authenticated
  halt "You must login to see this page!"
end

get '/login_with_http_basic_auth' do
  erb "HTTP Basic Auth"
end

get '/auth_at_provider' do
  auth_at_provider(params[:provider])
end

get '/oauth/:provider/callback' do
  provider = params[:provider]
  @user = login_from_access_token(provider)
  unless @user
    if @user = create_from_provider!(provider)
      erb "Success!"
    else
      erb "Failed!"
    end
  else
    
  end
end
