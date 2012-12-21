#
# A ListRule determines whether or not a taxon should be added to a list. 
# When a taxon is added to a list, the list will attempt to validate that
# taxon using all its ListRules.  Each ListRule stores the name of a class
# method in the Taxon model that returns true/false (the operator) and a
# polymorphic reference to some other object (the operand).  When the ListRule
# is applied, it calls the operator method with the operand as an argument. 
# If it returns true, the taxon gets in the list. Otherwise, it's Failsville.
#
class ListRule < ActiveRecord::Base
  belongs_to :list
  belongs_to :operand, :polymorphic => true
  
  #
  # Tests whether a taxon passes this rule or not.
  #
  def validates?(taxon)
    return false if taxon.blank?
    taxon.send(self.operator, self.operand)
  rescue ArgumentError => e
    raise e unless e.message =~ /wrong number of arguments/
    taxon.send(self.operator)
  end
  
  #
  # Pretty string representation of this rule, like "occurs in Berkeley, CA"
  #
  def terms
    operand_name = self.operand.to_plain_s if self.operand.respond_to?(:to_plain_s)
    operand_name ||= self.operand.name if self.operand.respond_to?(:name)
    operand_name ||= self.operand.to_s
    "%s %s" % [self.operator.gsub('_', ' ').gsub('?', ''), operand_name]
  end
end
