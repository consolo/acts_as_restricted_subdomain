require 'rubygems'
require 'test/unit'
require 'active_record'
require 'active_model'

$:.unshift "#{File.dirname(__FILE__)}/../"
$:.unshift "#{File.dirname(__FILE__)}/../lib/"

require 'init'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :agencies do |t|
      t.string :name
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
  acts_as_restricted_subdomains
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

    ["agency_1", "agency_2", "agency_3"].each do |code|
      Agency.create! :code => code
    end

    Thing.create! :agency_1
    Thing.create! :agency_2
    Thing.create! :agency_2
    Thing.create! :agency_3
    Thing.create! :agency_3
    Thing.create! :agency_3
  end

  def teardown
    teardown_db
  end
end

class AgencyTest < ActsAsRestrictedSubdomainBaseTest
  def test_agency_current
    Agency.current = "agency_1"
    assert_equal Agency.current, "agency_1"
  end
end

class ThingTest < ActsAsRestrictedSubdomainBaseTest

  def test_real_removal    
    assert_equal 6, Thing.count
    
    Agency.current = "agency_3"
    assert_equal 3, Thing.count
    assert_equal Agency.current.id, Agency.all.collect(&:agency_id).uniq
  end
end