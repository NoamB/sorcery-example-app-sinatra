class User < ActiveRecord::Base
  attr_accessible :email, :password, :password_confirmation, :authentications_attributes
  
  has_many :authentications, :dependent => :destroy
  accepts_nested_attributes_for :authentications
  validates_confirmation_of :password, :on => :create, :message => "should match confirmation"
  
  authenticates_with_sorcery!
end
