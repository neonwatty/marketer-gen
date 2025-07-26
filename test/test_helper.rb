ENV["RAILS_ENV"] ||= "test"

# SimpleCov must be started before any application code
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/vendor/'
  
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Helpers', 'app/helpers'
  add_group 'Mailers', 'app/mailers'
  add_group 'Policies', 'app/policies'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
end

require_relative "../config/environment"
require "rails/test_help"

# Configure test environment to handle assets

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Disable parallelization when running with coverage
    parallelize(workers: :number_of_processors) unless ENV['COVERAGE']

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    
    # Helper method for sign in path
    def sign_in_path
      new_session_path
    end
  end
end
