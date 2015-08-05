# Be sure to restart your server when you modify this file.

ActiveSupport::Inflector.inflections do |inflect|
  inflect.plural /^(.*)([Tt])axon$/i, '\1\2axa'
  inflect.singular /^(.*)([Tt])axa$/i, '\1\2axon'
  inflect.plural /^(.*)([Tt])axa$/i, '\1\2axa'
  
  inflect.plural /^(.*)([Pp])hylum$/i, '\1\2hyla'
  inflect.singular /^(.*)([Pp])hyla$/i, '\1\2hylum'
  
  inflect.plural /^(.*)([Gg])enus$/i, '\1\2enera'
  inflect.singular /^(.*)([Gg])enera$/i, '\1\2enus'
  
  inflect.plural /^(.*)([Pp])rotozoan$/i, '\1\2rotozoa'
  inflect.singular /^(.*)([Pp])rotozoa$/i, '\1\2rotozoan'
  
  inflect.plural /^(.*)([Ff])ugus$/i, '\1\2ungi'
  inflect.singular /^(.*)([Ff])ungi$/i, '\1\2ungus'
  inflect.singular /^(.*)([Ff])ungus$/i, '\1\2ungus'
  
  inflect.plural /^(.*)([Oo])ctopus$/i, '\1\2ctopi'
  inflect.singular /^(.*)([Oo])ctopi$/i, '\1\2ctopus'
  inflect.singular /^(.*)([Oo])ctopus$/i, '\1\2ctopus'
  
  inflect.irregular 'manzanita', 'manzanita'
  inflect.irregular 'gilia', 'gilia'
  inflect.irregular 'clarkia', 'clarkia'
  inflect.irregular 'fuschia', 'fuschia'
  inflect.irregular 'nutria', 'nutria'
  
  inflect.singular /^(.*)grass$/i, '\1grass'

  inflect.plural /^(.*)([Ii])bis$/i, '\1\2bises'
  inflect.singular /^(.*)([Ii])bises$/i, '\1\2bis'
  inflect.singular /^(.*)([Ii])bis$/i, '\1\2bis'
  
  inflect.plural /^(.*)([Ii])ris$/i, '\1\2rises'
  inflect.singular /^(.*)([Ii])rises$/i, '\1\2ris'
  inflect.singular /^(.*)([Ii])ris$/i, '\1\2ris'
  
  inflect.plural 'amanita', 'amanitas'
  inflect.singular 'amanita', 'amanita'
  inflect.singular 'amanitas', 'amanita'

  inflect.plural /^(.*)([Cc])ache$/i, '\1\2aches'
  inflect.singular /^(.*)([Cc])aches$/i, '\1\2ache'
  inflect.singular /^(.*)([Cc])ache$/i, '\1\2ache'
end
