class GoalRule < ActiveRecord::Base
  belongs_to :goal
  
  validates_presence_of :operator_class, :operator, :goal_id
  
  # ensure that by some weird coincidence there are not multiple definitions
  # of the same rule
  validates_uniqueness_of :goal_id,
                          :scope => [:operator_class, :operator, :arguments],
                          :message => "is already a valid rule"
  
  # validates? takes 'thing' and runs a test on it by calling the operator
  # via send.  validates? passes the dynamically called operator, 'thing'
  # along with anything defined in parameters. (parameters are stored in
  # the database as a pipe deliminated string).
  #
  # This requires that rules, which may defined as any class level method,
  # gracefully handle the objects they receive.
  def validates?(operand)
    # not really sure about this next line. It may be useful to allow each
    # rule to handle what to do with the operand itself.
    #
    # return false if thing.class.to_s != self.operator_class
    return Object.const_get(self.operator_class).send(self.operator.to_sym, operand, self.arguments.split('|'))
  end
end
