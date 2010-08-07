class Rule < ActiveRecord::Base
  belongs_to :ruler, :polymorphic => true
  belongs_to :operand, :polymorphic => true
  
  def validates?(subject)
    operand ? subject.send(operator, operand) : subject.send(operator)
  end
  
  def terms
    "must be #{operator} #{operand}".strip
  end
end
