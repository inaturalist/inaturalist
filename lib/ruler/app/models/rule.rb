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
    return "must be #{operator.humanize.downcase}".gsub('?', '') unless operand
    operand_name = if operand.respond_to?(:display_name)
      operand.display_name
    elsif operand.respond_to?(:name) && !operand.name.blank?
      operand.name
    elsif operand.respond_to?(:login)
      operand.login
    elsif operand.respond_to?(:title)
      operand.title
    else
      operand
    end
    "must be #{operator.humanize.downcase} #{operand_name}".strip.gsub('?', '')
  end
end
