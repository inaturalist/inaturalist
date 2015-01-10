module ActsAsSpammable
end

Dir["#{File.dirname(__FILE__)}/acts_as_spammable/**/*.rb"].each { |f| load(f) }
