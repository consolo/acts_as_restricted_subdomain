module RestrictedSubdomain
  SubdomainNotFound = Class.new(ActiveRecord::RecordNotFound)

  module Utils
    SUBDOMAIN_REGEX = /\./

    private

    def subdomain_from_host(host)
      host.split(SUBDOMAIN_REGEX).first
    end
  end
end
