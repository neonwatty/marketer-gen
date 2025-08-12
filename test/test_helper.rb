ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "ostruct"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    
    # Simple stubbing mechanism for tests
    def stub_method(klass, method_name, return_value)
      original_method = klass.instance_method(method_name) if klass.method_defined?(method_name)
      
      klass.define_method(method_name) do |*args|
        return_value
      end
      
      # Return a proc to restore the original method
      lambda do
        if original_method
          klass.define_method(method_name, original_method)
        else
          klass.remove_method(method_name)
        end
      end
    end
  end
end
