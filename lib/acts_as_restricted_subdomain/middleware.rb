module RestrictedSubdomain
  ##
  # Rack middleware to restrict db access by subdomain.
  #
  # Takes two important arguments: :through and :by. :through should be a class,
  # class name, or proc that returns the class of the model used to represent
  # the subdomain (defaults to Agency). :by should be the column name
  # of the field containing the subdomain (defaults to :code).
  #
  # Optional argument :global. This is a subdomain (or array) that should not
  # perform a subdomain lookup. Instead, the current subdomain will be left blank
  # and your application code will run "globally", with access to all agencies.
  # E.g. a login portal.
  #
  # Optional argument :not_found. Override the default subdomain not found response.
  # It's a proc that accepts a subdomain string and returns a Rack response.
  #
  class Middleware
    include RestrictedSubdomain::Utils

    # Default options
    DEFAULTS = {through: 'Agency', by: :code, header: nil, global: [], not_found: ->(subdomain) {
      body = "<h1>Subdomain Not Found</h1><p><em>#{subdomain}</em> is not a valid subdomain; are you sure you spelled it correctly?"
      [400, {'Content-Type' => 'text/html', 'Content-Length' => body.size.to_s}, [body]]
    }}

    # A reference to the model that holds the subdomains (either a class, class name, or proc returning the class
    attr_reader :subdomain_klass_option
    # The subdomain_klass column that maps to the request subdomain
    attr_reader :subdomain_column
    # Optionally look for the subdomain in an HTTP header instead of in the domain name
    attr_reader :subdomain_header
    # An array of global subdomains, i.e. subdomains that don't map to a subdomain_klass record
    attr_reader :global_subdomains
    # Proc that returns the Agency not found Rack response
    attr_reader :not_found

    def initialize(app, _options = {})
      @app = app
      options = DEFAULTS.merge(_options)
      @subdomain_klass_option = options.fetch(:through)
      @subdomain_column = options.fetch(:by)
      @subdomain_header = options[:header] ? "HTTP_#{options[:header].upcase.gsub('-', '_')}" : nil
      @global_subdomains = Array(options.fetch(:global))
      @not_found = options.fetch(:not_found)
    end

    def call(env)
      request_subdomain = subdomain_header ? env[subdomain_header] : subdomain_from_host(Rack::Request.new(env).host)

      if !request_subdomain.blank? and (self.global_subdomains.include?(request_subdomain) or (subdomain_klass.current = subdomain_klass.where({ self.subdomain_column => request_subdomain }).first))
        @app.call(env)
      else
        not_found.(request_subdomain)
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
