require 'action_controller'

module RestrictedSubdomain
  module Controller
    ##
    # == General
    #
    # Enables subdomain restrictions by adding middleware and helpers to
    # access the current subdomain through current_subdomain in the
    # controller.
    #
    # == Usage
    #
    # 1. Add the RestrictedSubdomain::Middleware middleware to your app.
    # See documentation for RestrictedSubdomain::Middleware.
    #
    # 2. Call use_restricted_subdomains in your ApplicationController.
    #
    # == Working Example
    #
    # For example, the usage of Agency and :code will work out thusly:
    #
    # In config/application.rb add:
    #   config.middleware.use RestrictedSubdomain::Middleware, through: 'Agency', by: :code
    #
    # In app/controllers/application.rb (or any other!) add:
    #   use_restricted_subdomains
    #
    # 1. Request hits http://secksi.example.com/login
    # 2. Subdomain becomes 'secksi'
    # 3. The corresponding 'Agency' with a ':code' of 'secksi' becomes the
    #    current subdomain. If it's not found, an RestrictedSubdomain::SubdomainNotFound
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
    def use_restricted_subdomains
      cattr_accessor :subdomain_klass, :subdomain_column

      if middleware = Rails.configuration.middleware.detect { |m| m === RestrictedSubdomain::Middleware }.try(:build, nil)
        # NewRelic wraps middleware in a proxy. I think the way we are using the
        # middleware is a bit non-traditional, so we need to get the actual
        # target of the proxy and call against that if we are passed in a proxy
        target = middleware.respond_to?(:target) ? middleware.target : middleware
        self.subdomain_klass = target.subdomain_klass
        self.subdomain_column = target.subdomain_column
      else
        raise "Please enable `RestrictedSubdomain::Middleware` middleware before calling `use_restricted_subdomains`"
      end

      helper_method :current_subdomain
      
      include RestrictedSubdomain::Utils
      include InstanceMethods
    end
  
    module InstanceMethods
      ##
      # Use as a before_filter to make sure there's a current_subdomain.
      # Useful if you're using global subdomains - e.g. a certain controller shouldn't be accessible from a global subdomain.
      #
      def require_subdomain
        raise RestrictedSubdomain::SubdomainNotFound if current_subdomain.nil?
      end

      ##
      # Use as a before_filter to make sure there ISN'T a current_subdomain.
      # Useful if you're using global subdomains - e.g. a certain controller shouldn ONLY be accessible from a global subdomain.
      #
      def require_no_subdomain
        raise RestrictedSubdomain::SubdomainNotFound if current_subdomain
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
      # a subhash keyed on the restricted subdomain symbol. If the current 
      # current subdomain is not set, it gracefully degrades to the normal session.
      #
      def session
        if current_subdomain
          request.session[current_subdomain_symbol] ||= {}
          request.session[current_subdomain_symbol] 
        else
          request.session
        end
      end

      ##
      # Forces all session assignments to a subhash keyed on the current
      # subdomain symbol, if found. Otherwise works just like normal.
      #
      def session=(*args)
        if current_subdomain
          request.session[current_subdomain_symbol] ||= {}
          request.session[current_subdomain_symbol] = args
        else
          request.session = args
        end
      end

      ##
      # Overwrite the default method so that session data from *other*
      # subdomains is kept.
      #
      def reset_session
        if current_subdomain
          copier = lambda { |sess, (key, val)| sess[key] = val unless key == current_subdomain_symbol; sess }
          new_session = request.session.inject({}, &copier)
          super
          new_session.inject(request.session, &copier)
        else
          super
        end
      end

      # Returns the subdomain from the current request. Inspects request.host to figure out
      # the subdomain by splitting on periods and using the first entry. This
      # implies that the subdomain should *never* have a period in the name.
      #
      # It can be useful to override this for testing with Capybara et all.
      #
      def request_subdomain
        subdomain_from_host(request.host)
      end
    end
  end
end

ActionController::Base.send :extend, RestrictedSubdomain::Controller
