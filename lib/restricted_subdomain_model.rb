module RestrictedSubdomain
  module Model
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
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
          class << self
            alias_method :find_every_with_subdomain, :find_every
            alias_method :calculate_with_subdomain, :calculate
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
    end
    
    module InstanceMethods # :nodoc:
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
      end
      
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
      
      public
      
      module ClassMethods
        def find_with_subdomain(*args)
          options = extract_options_from_args!(args) rescue args.extract_options!
          validate_find_options(options)
          set_readonly_option!(options)
          options[:with_subdomain] = true
          
          case args.first
            when :first then find_initial(options)
            when :all   then find_every(options)
            else             find_from_ids(args, options)
          end
        end
        
        def count_with_subdomain(*args)
          calculate_with_subdomain(:count, *construct_subdomain_options_from_legacy_args(*args))
        end
        
        def construct_subdomain_options_from_legacy_args(*args)
          options     = {}
          column_name = :all
          
          # We need to handle
          #   count()
          #   count(options={})
          #   count(column_name=:all, options={})
          #   count(conditions=nil, joins=nil)      # deprecated
          if args.size > 2
            raise ArgumentError, "Unexpected parameters passed to count(options={}): #{args.inspect}"
          elsif args.size > 0
            if args[0].is_a?(Hash)
              options = args[0]
            elsif args[1].is_a?(Hash)
              column_name, options = args
            else
              options.merge!(:conditions => args[0])
              options.merge!(:joins      => args[1]) if args[1]
            end
          end
          
          [column_name, options]
        end
        
        def count(*args)
          with_subdomain_scope { count_with_subdomain(*args) }
        end
        
        def calculate(*args)
          with_subdomain_scope { calculate_with_subdomain(*args) }
        end
        
        protected
        
        def with_subdomain_scope(&block)
          if subdomain_klass.current
            subdomain_id = subdomain_klass.current[subdomain_klass.primary_key]
            with_scope({ :find => { :conditions => ["#{table_name}.#{subdomain_symbol}_id = ?", subdomain_id ] } }, :merge, &block)
          else
            with_scope({}, :merge, &block)
          end 
        end
        
        private
        
        def find_every(options)
          options.delete(:with_subdomain) ?
            find_every_with_subdomain(options) :
            with_subdomain_scope { find_every_with_subdomain(options) }
        end
      end
    end
  end
end
