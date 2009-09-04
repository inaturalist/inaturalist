#
# Flaggings mark data objects as needing attention.  Initially, this will be
# for taxa that need the attention of a curator.
#
class Flagging < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :user
  belongs_to :resolver, :class_name => 'User', :foreign_key => 'resolver_id'
  validates_presence_of :resolver, :if => Proc.new {|f| f.resolved? }
  validates_presence_of :user, :taxon
end
