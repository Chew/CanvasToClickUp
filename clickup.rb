# Class to interface with the ClickUp API
class ClickUp
  # Creates a new task in ClickUp in the configured list
  def self.create_task(body)
    JSON.parse RestClient.post("#{BASE_URLS[:clickup]}/list/#{CLICKUP_LIST_ID}/task",
                               body.to_json,
                               Authorization: TOKENS[:clickup],
                               content_type: :json,
                               accept: :json)
  end
end