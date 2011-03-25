class User < ActiveRecord::Base
  attr_accessible :email, :password, :password_confirmation, :authentications_attributes
  
  has_many :authentications, :dependent => :destroy
  accepts_nested_attributes_for :authentications
  validates_confirmation_of :password, :on => :create, :message => "should match confirmation"
  
  activate_sorcery! do |config|
    config.username_attribute_name                      = :email
    
    config.user_activation_mailer                       = SorceryMailer
    
    config.reset_password_mailer                        = SorceryMailer
    config.reset_password_expiration_period             = 10.minutes
    config.reset_password_time_between_emails           = nil
        
    config.activity_timeout                             = 1.minutes
  
    config.consecutive_login_retries_amount_limit       = 10
    config.login_lock_time_period                       = 2.minutes
    
    config.authentications_class                        = Authentication
  end
end
