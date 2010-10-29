class Rule < ActiveRecord::Base
  belongs_to :ruler, :polymorphic => true
  belongs_to :operand, :polymorphic => true
  validates_presence_of :operator
  before_validation :nilify_operand_if_blank
  
  def nilify_operand_if_blank
    self.operand = nil if operand_type.blank? || operand_id.blank?
  end
  
  def validates?(subject)
    operand ? subject.send(operator, operand) : subject.send(operator)
  end
  
  def terms
    return "must be #{operator}".gsub('?', '') unless operand
    operand_name = operand.try(:display_name) || operand
    "must be #{operator} #{operand_name}".strip.gsub('?', '')
  end
end
