class Rule < ActiveRecord::Base
  belongs_to :ruler, :polymorphic => true
  belongs_to :operand, :polymorphic => true
  validates_presence_of :operator
  
  def validates?(subject)
    Rails.logger.debug "[DEBUG] operand: #{operand}"
    Rails.logger.debug "[DEBUG] operator: #{operator}"
    Rails.logger.debug "[DEBUG] subject: #{subject}"
    operand ? subject.send(operator, operand) : subject.send(operator)
  end
  
  def terms
    operand_name = operand.try(:display_name) || operand
    Rails.logger.debug "[DEBUG] operand.try(:display_name): #{operand.try(:display_name)}"
    "must be #{operator} #{operand_name}".strip
  end
end
