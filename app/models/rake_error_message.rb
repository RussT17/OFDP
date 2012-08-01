class RakeErrorMessage < ActiveRecord::Base
  attr_accessible :message, :backtrace
end