Gem::Specification.new do |s|
  s.name          = 'acts_as_restricted_subdomain'
  s.version       = '4.2.0'
  s.authors       = ['Andrew Coleman', 'Taylor Redden']
  s.email         = 'developers@consoloservices.com'
  s.summary       = 'Acts As Restricted Subdomain'
  s.description   = 'Restrict Active Record Calls based on a Foreign key'
  s.homepage      = 'https://redmine.consoloservices.com'
  s.files         = `git ls-files`.split("\n")
  s.require_path  = 'lib'
    
  s.add_dependency "activerecord"
end
