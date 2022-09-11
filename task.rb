# frozen_string_literal: true

# A wrapper for the task JSON from ClickUp
class Task
  def initialize(data)
    @data = data
  end

  def id
    @data['id']
  end

  def name
    @data['name']
  end

  def description
    @data['description'].to_s.strip
  end

  def custom_fields
    @data['custom_fields']
  end

  def tags
    @data['tags']
  end

  def status
    @data['status']['status']
  end

  # @return [Time, nil] the time the task was created
  def due_date
    return nil if @data['due_date'].nil?

    Time.at @data['due_date'].to_i / 1000
  end

  def start_date
    return nil if @data['start_date'].nil?

    Time.at @data['start_date'].to_i / 1000
  end

  # @return [String] a link to the canvas html_url
  # @see Assignment#url
  def canvas_link
    custom_fields.find { |field| field['name'] == 'Canvas Link' }['value']
  end

  # @return [String] the name of the class based on the custom field
  def class_name
    field = custom_fields.find { |custom_field| custom_field['name'] == 'Class' }

    value = field['value']
    field['type_config']['options'][value]['name']
  end

  def grade
    custom_fields.find { |field| field['name'] == 'Grade' }['value']
  end

  # Whether or not this task is ignored
  def ignored?
    !tags.find { |tag| tag['name'].downcase == 'ignored' }.nil?
  end
end
