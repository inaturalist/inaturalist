require ::File.expand_path('../model_adapter',  __FILE__)

#require the name providers
require 'ratatosk/name_providers/catalogue_of_life'
require 'ratatosk/name_providers/ubio'
require 'ratatosk/name_providers/nzor'

class TaxonNameAdapterError < StandardError; end
class TaxonAdapterError < StandardError; end
class NameProviderError < StandardError; end
