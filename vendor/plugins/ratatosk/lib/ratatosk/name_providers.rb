require 'ratatosk/model_adapter'

#require the name providers
require 'ratatosk/name_providers/catalogue_of_life'
require 'ratatosk/name_providers/ubio'

class TaxonNameAdapterError < StandardError; end
class TaxonAdapterError < StandardError; end
class NameProviderError < StandardError; end
