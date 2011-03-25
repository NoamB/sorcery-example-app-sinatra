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

require 'action_mailer'
ActionMailer::Base.perform_deliveries = false
ActionMailer::Base.raise_delivery_errors = false

require File.join(File.dirname(__FILE__),'sorcery_mailer')

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
require File.join(File.dirname(__FILE__),'authentication')
require File.join(File.dirname(__FILE__),'user')

# filters
['/test_logout','/some_action','/test_should_be_logged_in'].each do |patt|
  before patt do
    require_login
  end
end

before '/test_http_basic_auth' do
  require_login_from_http_basic
end

# actions
get '/' do
  @notice = session[:notice]
  @alert = session[:alert]
  session.clear
  @users = User.all
  erb :'users/index'
end

get '/users/new' do
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

# blalll
get '/test_login' do
  @user = login(params[:username],params[:password])
  @current_user = current_user
  @logged_in = logged_in?
  erb :test_login
end

get '/test_logout' do
  session[:user_id] = User.first.id
  logout
  @current_user = current_user
  @logged_in = logged_in?
end

get '/test_current_user' do
  session[:user_id] = params[:id]
  current_user
end

get '/some_action' do
  erb ''
end

post '/test_return_to' do
  session[:return_to_url] = params[:return_to_url] if params[:return_to_url]
  @user = login(params[:username], params[:password])
  return_or_redirect_to(:some_action)
end

get '/test_should_be_logged_in' do
  erb ''
end

def test_not_authenticated_action
  halt "test_not_authenticated_action"
end

def not_authenticated2
  @session = session
  save_instance_vars
  redirect '/'
end

# remember me

post '/test_login_with_remember' do
  @user = login(params[:username], params[:password])
  remember_me!
  erb ''
end

post '/test_login_with_remember_in_login' do
  @user = login(params[:username], params[:password], params[:remember])
  erb ''
end

get '/test_login_from_cookie' do
  @user = current_user
  erb ''
end

# http_basic

get '/test_http_basic_auth' do
  erb "HTTP Basic Auth"
end

# oauth

get '/auth_at_provider_test' do
  auth_at_provider(:twitter)
end

get '/test_login_from_access_token' do
  if @user = login_from_access_token(:twitter)
    erb "Success!"
  else
    erb "Failed!"
  end
end

# oauth2

get '/auth_at_provider_test2' do
  auth_at_provider(:facebook)
end

get '/test_login_from_access_token2' do
  if @user = login_from_access_token(:facebook)
    erb "Success!"
  else
    erb "Failed!"
  end
end

get '/test_create_from_provider' do
  provider = params[:provider]
  login_from_access_token(provider)
  if @user = create_from_provider!(provider)
    erb "Success!"
  else
    erb "Failed!"
  end
end