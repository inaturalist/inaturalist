module FlowTasksHelper
  
  def flow_task_redirect_url(flow_task)
    return flow_task_url(flow_task) if flow_task.redirect_url.blank?
    url = flow_task.redirect_url
    if url =~ /^\// || url =~ /^http/
      url += if url =~ /\?/
        "&flow_task_id=#{flow_task.id}"
      else
        "?flow_task_id=#{flow_task.id}"
      end
    else
      send(url, :flow_tas_id => flow_task.id)
    end
  end
  
end