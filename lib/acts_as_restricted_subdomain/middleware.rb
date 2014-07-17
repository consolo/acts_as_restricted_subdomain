module RestrictedSubdomain
  ##
  # Rack middleware to restrict db access by subdomain.
  #
  # Takes two arguments: :through and :by. :through should be a class,
  # class name, or proc that returns the class of the model used to represent
  # the subdomain (defaults to Agency). :by should be the column name
  # of the field containing the subdomain (defaults to :code).
  #
  # Optional argument :global. This is a subdomain (or array) that should not
  # perform a subdomain lookup. Instead, the current subdomain will be left blank
  # and your application code will run "globally", with access to all agencies.
  # E.g. a login portal.
  #
  class Middleware
    include RestrictedSubdomain::Utils

    # Default options
    DEFAULTS = {through: 'Agency', by: :code, global: []}

    # A reference to the model that holds the subdomains (either a class, class name, or proc returning the class
    attr_reader :subdomain_klass_option
    # The subdomain_klass column that maps to the request subdomain
    attr_reader :subdomain_column
    # An array of global subdomains, i.e. subdomains that don't map to a subdomain_klass record
    attr_reader :global_subdomains

    def initialize(app, _options = {})
      @app = app
      options = DEFAULTS.merge(_options)
      @subdomain_klass_option = options.fetch(:through)
      @subdomain_column = options.fetch(:by)
      @global_subdomains = Array(options.fetch(:global))
    end

    def call(env)
      request = Rack::Request.new(env)
      request_subdomain = subdomain_from_host(request.host)

      if self.global_subdomains.include?(request_subdomain) or (subdomain_klass.current = subdomain_klass.where({ self.subdomain_column => request_subdomain }).first)
        @app.call(env)
      else
        raise RestrictedSubdomain::SubdomainNotFound
      end
    ensure
      self.subdomain_klass.current = nil
    end

    # Returns the subdomain class
    def subdomain_klass
      @subdomain_klass ||= if self.subdomain_klass_option.respond_to?(:call)
        self.subdomain_klass_option.call
      elsif self.subdomain_klass_option.respond_to?(:constantize)
        self.subdomain_klass_option.constantize
      else
        self.subdomain_klass_option
      end
    end
  end
end
