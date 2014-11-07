require 'rubygems'
require 'test/unit'
require 'active_record'
require "active_support"
require 'active_model'

$:.unshift "#{File.dirname(__FILE__)}/../"
$:.unshift "#{File.dirname(__FILE__)}/../lib/"

require 'acts_as_restricted_subdomain/utils'
require 'acts_as_restricted_subdomain/middleware'
require 'acts_as_restricted_subdomain/controller'
require 'acts_as_restricted_subdomain/model'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :agencies do |t|
      t.string :code
      t.timestamps
    end

    create_table :things do |t|
      t.integer :agency_id
      t.timestamps
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Agency < ActiveRecord::Base
  use_for_restricted_subdomains
  validates_uniqueness_of :code
  def to_s
    self.code
  end
end


class Thing < ActiveRecord::Base
  acts_as_restricted_subdomain
end



#############
# Actual Test
#############
class ActsAsRestrictedSubdomainBaseTest < ActiveSupport::TestCase
  def assert_empty(collection)
    assert(collection.respond_to?(:empty?) && collection.empty?)
  end
  
  def setup
    setup_db
      
    agency_1 = Agency.create! :code => "agency_1"
    agency_2 = Agency.create! :code => "agency_2"
    agency_3 = Agency.create! :code => "agency_3"
      
    Agency.current = "agency_1"  
    Thing.create!
    
    Agency.current = "agency_2"
    Thing.create!
    Thing.create!
    
    Agency.current = "agency_3"
    Thing.create!
    Thing.create!
    Thing.create!
    
    Agency.current = nil
  end

  def teardown
    teardown_db
  end
end

class AgencyTest < ActsAsRestrictedSubdomainBaseTest
  def test_agency_current
    Agency.current = "agency_1"
    assert_equal Agency.current.code, "agency_1"
  end
end

class ThingTest < ActsAsRestrictedSubdomainBaseTest  
  def test_restricted_to_subdomain
    assert_equal true, Thing.restricted_to_subdomain?
  end
  
  def validates_presence_of_agency
    Agency.current = nil
    thing = Thing.create!
    assert_equal thing.errors.size, 1
  end
  
  def test_unset_agency_count 
    Agency.current = nil   
    assert_equal 6, Thing.count
  end
  
  def test_set_agency_count
    Agency.current = "agency_3"
    assert_equal 3, Thing.count
  end
  
  def test_set_agency_find_all
    Agency.current = "agency_3"
    assert_equal [Agency.current.id], Thing.all.collect(&:agency_id).uniq
  end
end
