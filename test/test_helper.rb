ENV['RAILS_ENV'] ||= 'test'

Warning.singleton_class.prepend(Module.new do
  def warn(msg, **kw) # rubocop:disable Naming/MethodParameterName
    return if msg.include?('rack-test') && msg.include?('literal string will be frozen')

    super
  end
end)

require_relative '../config/environment'
require 'rails/test_help'
require_relative 'test_helpers/session_test_helper'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
