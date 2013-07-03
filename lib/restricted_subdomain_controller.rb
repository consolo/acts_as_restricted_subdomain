require 'action_controller'

module RestrictedSubdomain
  module Controller
    ##
    # == General
    #
    # Enables subdomain restrictions by adding a before_filter and helper to
    # access the current subdomain through current_subdomain in the
    # controller.
    #
    # == Usage
    #
    # Takes two arguments: :through and :by. :through should be a class of the
    # model used to represent the subdomain (defaults to Agency) and the :by
    # should be the column name of the field containing the subdomain
    # (defaults to :code).
    #
    # == Working Example
    #
    # For example, the usage of Agency and :code will work out thusly:
    #
    # In app/controllers/application.rb (or any other!) add:
    #   use_restricted_subdomains :through => 'Agency', :by => :code
    #
    # 1. Request hits http://secksi.example.com/login
    # 2. Subdomain becomes 'secksi'
    # 3. The corresponding 'Agency' with a ':code' of 'secksi' becomes the
    #    current subdomain. If it's not found, an ActiveRecord::RecordNotFound
    #    is thrown to automatically raise a 404 not found.
    #
    # == account_location
    #
    # This plugin is very similar to the functionality of the account_location
    # plugin written by DHH. There are three basic differences between them,
    # though. This plugin allows for any model and any column, not just
    # @account.username like account_plugin. I also wanted epic failure if a
    # subdomain was not found, not just pretty "uh oh" or a default page.
    # There should be no choice -- just finished. The plugin also integrates
    # with the model, you cannot access information outside of your domain
    # for any model tagged with subdomain restrictions. If your users are
    # limited to a subdomain, you cannot in any way access the users from
    # another subdomain simply by typing User.find(params[:random_id]).
    # It should also provide an epic failure.
    #
    # This plugin provides that kind of separation. It was designed to provide
    # separation of data in a medical application so as to run _n_ different
    # instances of an application in _1_ instance of the application, with
    # software restrictions that explicitly and implicitly forbid access
    # outside of your natural subdomain.
    #
    # Funny story: I actually completely finished this part of the plugin...
    # Then i discovered that account_location existed and did pretty much the
    # same thing without any meta-programming. Good times :)
    #
    def use_restricted_subdomains(opts = {})
      options = {
        :through => 'Agency',
        :by => :code
      }.merge(opts)
      
      respond_to?(:prepend_around_action) ? prepend_around_action(:within_request_subdomain) : prepend_around_filter(:within_request_subdomain)
      
      cattr_accessor :subdomain_klass, :subdomain_column
      self.subdomain_klass = options[:through].constantize
      self.subdomain_column = options[:by]
      helper_method :current_subdomain
      
      include InstanceMethods
    end
  
    module InstanceMethods
      ##
      # Sets the current subdomain model. Inspects request.host to figure out
      # the subdomain by splitting on periods and using the first entry. This
      # implies that the subdomain should *never* have a period in the name.
      #
      def within_request_subdomain
        self.subdomain_klass.current = request.host.split(/\./).first
        raise ActiveRecord::RecordNotFound if self.subdomain_klass.current.nil?
        begin
          yield if block_given?
        ensure
          self.subdomain_klass.current = nil
        end
      end

      ##
      # Returns the current subdomain model, or nil if none.
      # It respects Agency.each_subdomain, Agency.with_subdomain and Agency.without_subdomain.
      #
      def current_subdomain
        self.subdomain_klass.current
      end
    
      ##
      # Returns a symbol of the current subdomain. So, something like
      # http://secksi.example.com returns :secksi
      #
      def current_subdomain_symbol
        if current_subdomain
          current_subdomain.send(self.subdomain_column).to_sym
        else
          nil
        end
      end
    
      ##
      # Overwrite the default accessor that will force all session access to
      # a subhash keyed on the restricted subdomain symbol. Only works if
      # the current subdomain is found, gracefully degrades if missing. 
      #
      def session
        if current_subdomain
          request.session[current_subdomain_symbol] ||= {}
          request.session[current_subdomain_symbol] 
        else
          request.session
        end
      end
    end
  end
end

ActionController::Base.send :extend, RestrictedSubdomain::Controller
