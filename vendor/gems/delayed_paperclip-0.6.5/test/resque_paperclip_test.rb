require 'test/test_helper'
gem 'resque'
require 'resque'

class ResquePaperclipTest < Test::Unit::TestCase
  def setup
    # Make sure that we just test Resque in here
    Object.send(:remove_const, :Delayed) if defined? Delayed

    Resque.remove_queue(:paperclip)
    reset_dummy
  end

  def test_enqueue_job_if_source_changed
    @dummy.stubs(:image_changed?).returns(true)

    original_job_count = Resque.size(:paperclip)
    @dummy.enqueue_job_for_image

    assert_equal original_job_count + 1, Resque.size(:paperclip)
  end

  def test_perform_job
    Paperclip::Attachment.any_instance.expects(:reprocess!)

    @dummy.save!
    ResquePaperclipJob.perform(@dummy.class.name, @dummy.id, :image)
  end

  def test_after_callback_is_functional
    @dummy_class.send(:define_method, :done_processing) { puts 'done' }
    @dummy_class.after_image_post_process :done_processing    
    Dummy.any_instance.expects(:done_processing)

    @dummy.save!
    ResquePaperclipJob.perform(@dummy.class.name, @dummy.id, :image)
  end
  
  def test_processing_column_kept_intact
    @dummy = reset_dummy(true)
    
    @dummy.stubs(:image_changed?).returns(true)
    Paperclip::Attachment.any_instance.stubs(:reprocess!).raises(StandardError.new('oops'))

    @dummy.save!
    assert @dummy.image_processing?
    
    worker = Resque::Worker.new(:paperclip)
    worker.process
    
    assert @dummy.reload.image_processing?
  end
end