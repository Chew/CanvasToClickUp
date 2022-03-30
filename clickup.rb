# Class to interface with the ClickUp API
class ClickUp
  # Creates a new task in ClickUp in the configured list
  def self.create_task(body)
    JSON.parse RestClient.post("#{BASE_URLS[:clickup]}/list/#{CLICKUP_LIST_ID}/task",
                               body.to_json,
                               Authorization: TOKENS[:clickup],
                               content_type: :json,
                               accept: :json)
  rescue RestClient::BadRequest => e
    print "Could not create task! #{e.response.body}"
  end

  # Updates a task on ClickUp
  # @param id [String] The task ID
  # @param update [Hash] The update data
  def self.update_task(id, update)
    JSON.parse RestClient.put("#{BASE_URLS[:clickup]}/task/#{id}",
                              update.to_json,
                              Authorization: TOKENS[:clickup],
                              content_type: :json,
                              accept: :json)
  rescue RestClient::BadRequest => e
    print "Could not update task! #{e.response.body}"
  end
end