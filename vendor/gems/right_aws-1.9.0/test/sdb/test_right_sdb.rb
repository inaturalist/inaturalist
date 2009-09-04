require File.dirname(__FILE__) + '/test_helper.rb'

class TestSdb < Test::Unit::TestCase

  def setup
    STDOUT.sync  = true
    @domain = 'right_sdb_awesome_test_domain'
    @item   = 'toys'
    @attr   = { 'Jon' => %w{beer car} }
    # Interface instance
    @sdb    = Rightscale::SdbInterface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key)
  end

  SDB_DELAY = 2
  
  def wait(delay, msg='')
    print "waiting #{delay} seconds #{msg}"
    while delay>0 do
      delay -= 1
      print '.'
      sleep 1
    end
    puts
  end

  #---------------------------
  # Rightscale::SdbInterface
  #---------------------------

  def test_00_delete_domain
    # delete the domain to reset all the things
    assert @sdb.delete_domain(@domain), 'delete_domain fail'
    wait SDB_DELAY, 'after domain deletion'
  end
  
  def test_01_create_domain
    # check that domain does not exist
    assert !@sdb.list_domains[:domains].include?(@domain)
    # create domain
    assert @sdb.create_domain(@domain), 'create_domain fail'
    wait SDB_DELAY, 'after domain creation'
    # check that we have received new domain from Amazin
    assert @sdb.list_domains[:domains].include?(@domain)
  end

  def test_02_put_attributes
    # put attributes
    assert @sdb.put_attributes(@domain, @item, @attr)
    wait SDB_DELAY, 'after putting attributes'
  end
  
  def test_03_get_attributes
    # get attributes
    values = @sdb.get_attributes(@domain, @item)[:attributes]['Jon'].to_a.sort
    # compare to original list
    assert_equal values, @attr['Jon'].sort
  end

  def test_04_add_attributes
    # add new attribute
    new_value = 'girls'
    @sdb.put_attributes @domain, @item, {'Jon' => new_value}
    wait SDB_DELAY, 'after putting attributes'
    # get attributes ('girls' must be added to already existent attributes)
    values = @sdb.get_attributes(@domain, @item)[:attributes]['Jon'].to_a.sort
    assert_equal values, (@attr['Jon'] << new_value).sort
  end
  
  def test_05_replace_attributes
    # replace attributes
    @sdb.put_attributes @domain, @item, {'Jon' => 'pub'}, :replace
    wait SDB_DELAY, 'after replacing attributes'
    # get attributes (all must be removed except of 'pub')
    values = @sdb.get_attributes(@domain, @item)[:attributes]['Jon']
    assert_equal values, ['pub']
  end
  
  def test_06_delete_attribute
    # add value 'girls' and 'vodka' to 'Jon'
    @sdb.put_attributes @domain, @item, {'Jon' => ['girls','vodka']}
    wait SDB_DELAY, 'after adding attributes'
    # get attributes ('girls' and 'vodka' must be added 'pub')
    values = @sdb.get_attributes(@domain, @item)[:attributes]['Jon'].to_a.sort
    assert_equal values, ['girls', 'pub', 'vodka']
    # delete a single value 'girls' from attribute 'Jon'
    @sdb.delete_attributes @domain, @item, 'Jon' => ['girls']
    wait SDB_DELAY, 'after the deletion of attribute'
    # get attributes ('girls' must be removed)
    values = @sdb.get_attributes(@domain, @item)[:attributes]['Jon']
    assert_equal values, ['pub', 'vodka']
    # delete all values from attribute 'Jon'
    @sdb.delete_attributes @domain, @item, ['Jon']
    wait SDB_DELAY, 'after the deletion of attributes'
    # get attributes (values must be empty)
    values = @sdb.get_attributes(@domain, @item)[:attributes]['Jon']
    assert_equal values, nil
  end

  def test_07_delete_item
    @sdb.put_attributes @domain, @item, {'Volodya' => ['girls','vodka']}
    wait SDB_DELAY, 'after adding attributes'
    # get attributes ('girls' and 'vodka' must be there)
    values = @sdb.get_attributes(@domain, @item)[:attributes]['Volodya'].to_a.sort
    assert_equal values, ['girls', 'vodka']
    # delete an item
    @sdb.delete_attributes @domain, @item
    # get attributes (values must be empty)
    values = @sdb.get_attributes(@domain, @item)[:attributes]['Volodya']
    assert_equal values, nil
  end  
  
  def test_08_query
    # add some values for query
    @sdb.put_attributes @domain, @item, {'Jon' => ['girls','vodka']}
    wait SDB_DELAY, 'after adding attributes'
    items = @sdb.query(@domain, ['[?=?]', 'Jon','vodka'])[:items]
    assert_equal items.size, 1
    assert_equal items.first, @item
  end
  
  def test_09_signature_version_0 
    sdb    = Rightscale::SdbInterface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key, :signature_version => '0') 
    item   = 'toys' 
    # TODO: need to change the below test.  I think Juergen's intention was to include some umlauts in the values
    # put attributes 
    # mhhh... Not sure how to translate this: hÃ¶lzchehn klÃ¶tzchen grÃŒnspan buÃe... Lets assume this is:
    attributes = { 'Jurgen' => %w{kitten puppy chickabiddy piglet} } 
    assert sdb.put_attributes(@domain, item, attributes) 
    wait SDB_DELAY, 'after putting attributes' 
    # get attributes 
    values = sdb.get_attributes(@domain, item)[:attributes]['Jurgen'].to_a.sort 
    # compare to original list 
    assert_equal values, attributes['Jurgen'].sort 
    # check that the request has correct signature version
    assert sdb.last_request.path.include?('SignatureVersion=0')
  end 
  
  def test_10_array_of_attrs
    item = 'multiples'
    assert_nothing_thrown "Failed to put multiple attrs" do
      @sdb.put_attributes(@domain, item, {:one=>1, :two=>2, :three=>3})
    end
  end
  
  def test_11_zero_len_attrs
    item = 'zeroes'
    assert_nothing_thrown "Failed to put zero-length attributes" do
      @sdb.put_attributes(@domain, item, {:one=>"", :two=>"", :three=>""})
    end
  end
  
  def test_12_nil_attrs
    item = 'nils'
    res = nil
    assert_nothing_thrown do
      @sdb.put_attributes(@domain, item, {:one=>nil, :two=>nil, :three=>'chunder'})
    end
    assert_nothing_thrown do
      res = @sdb.get_attributes(@domain, item)
    end
    assert_nil(res[:attributes]['one'][0])
    assert_nil(res[:attributes]['two'][0])
    assert_not_nil(res[:attributes]['three'][0])
  end
  
  def test_13_url_escape
    item = 'urlescapes'
    content = {:a=>"one & two & three",
               :b=>"one ? two / three"}
    @sdb.put_attributes(@domain, item, content)

    res = @sdb.get_attributes(@domain, item)
    assert_equal(content[:a], res[:attributes]['a'][0])
    assert_equal(content[:b], res[:attributes]['b'][0])
  end
  
  def test_14_put_attrs_by_post
    item = 'reqgirth'
    i = 0
    sa = ""
    while(i < 64) do
      sa += "aaaaaaaa"
      i += 1
    end
    @sdb.put_attributes(@domain, item, {:a => sa, :b => sa, :c => sa, :d => sa, :e => sa})
  end
  
  # Keep this test last, because it deletes the domain...
  def test_20_delete_domain
    assert @sdb.delete_domain(@domain), 'delete_domain fail'
    wait SDB_DELAY, 'after domain deletion'
    # check that domain does not exist
    assert !@sdb.list_domains[:domains].include?(@domain)
  end
  
  
  
end