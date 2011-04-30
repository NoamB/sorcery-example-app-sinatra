require_relative 'myapp'
require "test/unit"
require 'rack/test'

ENV['RACK_ENV'] = 'test'

ActionMailer::Base.delivery_method = :test

class MyTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Sorcery::TestHelpers::Sinatra

  def app
    ::Sinatra::Application.new
  end

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    ::Sinatra::Application.rack_test_session = rack_test_session

    @user = User.create!(:email => "bla@bla.com", :password => 'secret')
    @user.activate!
    p @user
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    User.delete_all
  end

  def test_root_url
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('Login')
  end

  def test_login
    post '/login', :email => 'bla@bla.com', :password => 'secret'
    assert_equal 302, last_response.status
  end

  def test_logout
    login_user
    get '/logout'
    assert_equal 302, last_response.status
  end
end