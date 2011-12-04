# Include hook code here
require 'table_builder'
 
ActionView::Base.send :include, TableHelper
ActionView::Base.send :include, CalendarHelper