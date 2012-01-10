require 'active_record'

module RestrictedSubdomain
  module Model
    ##
    # This method will mark a class as the subdomain model. It expects to
    # contain the subdomain in a column. You can override the default (:code)
    # by passing a :by parameter. That column will be validated for presence
    # and uniqueness, so be sure to add an index on that column.
    #
    # This will add a cattr_accessor of current which will always contain
    # the current subdomain requested from the controller.
    #
    # A method for iterating over each subdomain model is also provided,
    # called each_subdomain. Pass a block and do whatever you need to do
    # restricted to a particular scope of that subdomain. Useful for console
    # and automated tasks where each subdomain has particular features that
    # may differ from each other.
    #
    # Example:
    #   class Agency < ActiveRecord::Base
    #     use_for_restricted_subdomains :by => :code
    #   end
    #
    def use_for_restricted_subdomains(opts = {})
      options = {
        :by => :code
      }.merge(opts)
      
      validates_presence_of options[:by]
      validates_uniqueness_of options[:by]
      cattr_accessor :current
      
      self.class_eval <<-RUBY
        def self.each_subdomain(&blk)
          old_current = self.current
          @_current_subdomains ||= self.find(:all)
          @_current_subdomains.each do |subdomain|
            self.current = subdomain
            yield blk
          end
          self.current = old_current
        end
        
        def self.current=(other)
          if other.is_a?(String) or other.is_a?(Symbol)
            @@current = self.send("find_by_#{options[:by]}", other)
          else
            @@current = other
          end
        end
      RUBY
    end
    
    ##
    # This method marks a model as restricted to a subdomain. This means that
    # it will have an association to whatever class models your subdomain,
    # see use_for_restricted_subdomains. It overrides the default find method
    # to always include a subdomain column parameter. You need to pass the
    # subdomain class symbol and column (defaults klass to :agency).
    #
    # Adds validation for the column and a belongs_to association.
    #
    # This does not add any has_many associations in your subdomain class.
    # That is an exercise left to the user, sorry. Also beware of
    # validates_uniqueness_of. It should be scoped to the foreign key.
    #
    # Example:
    #   
    #   class Widget < ActiveRecord::Base
    #     acts_as_restricted_subdomain :through => :subdomain
    #   end
    #   
    #   class Subdomain < ActiveRecord::Base
    #     use_for_restricted_subdomains :by => :name
    #   end
    #
    # Special thanks to the Caboosers who created acts_as_paranoid. This is
    # pretty much the same thing, only without the delete_all bits.
    #
    def acts_as_restricted_subdomain(opts = {})
      options = { :through => :agency }.merge(opts)
      unless restricted_to_subdomain?
        cattr_accessor :subdomain_symbol, :subdomain_klass
        self.subdomain_symbol = options[:through]
        self.subdomain_klass = options[:through].to_s.camelize.constantize
        belongs_to options[:through]
        before_create :set_restricted_subdomain_column
        
        self.class_eval do 
          default_scope Proc.new { self.subdomain_klass.current ? where("#{self.subdomain_symbol}_id" => self.subdomain_klass.current.id ) : nil }
        end
        
        include InstanceMethods
      end
    end
    
    ##
    # Checks to see if the class has been restricted to a subdomain.
    #
    def restricted_to_subdomain?
      self.included_modules.include?(InstanceMethods)
    end
    
    module InstanceMethods
      private
      def set_restricted_subdomain_column
        self.send("#{subdomain_symbol}=", subdomain_klass.current)
        if self.send("#{subdomain_symbol}_id").nil?
          self.errors.add(subdomain_symbol, 'is missing')
          false
        else
          true
        end
      end
    end
  end
end

ActiveRecord::Base.send :extend, RestrictedSubdomain::Model