# frozen_string_literal: true

Dir[
  "#{File.dirname( __FILE__ )}/qdrant_model/acts_as_qdrant_model.rb"
].each {| f | load( f ) }
