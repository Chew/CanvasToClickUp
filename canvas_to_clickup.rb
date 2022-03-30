# frozen_string_literal: true

require 'json'
require "net/http"
require 'nokogiri'
require 'rest-client'
require 'yaml'
require "uri"

require_relative './assignment'
require_relative './clickup'
require_relative './custom_field'
require_relative './task'

# Always load example first in case of missing methods
require_relative './custom.example'

# Attempt to load custom.rb file, if it exists. Otherwise, use default values.
begin
  require_relative './custom'
rescue LoadError
  # No custom.rb file found
end

# Load the config.yml relative to this file
CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), 'config.yml'))

BASE_URLS = {
  canvas: "#{CONFIG['canvas_url']}/api/v1",
  canvas_graphql: "#{CONFIG['canvas_url']}/api/graphql",
  clickup: CONFIG['clickup_url']
}.freeze

TOKENS = {
  canvas: CONFIG['canvas_token'],
  clickup: CONFIG['clickup_token']
}.freeze

USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.138 Safari/537.36'

CLICKUP_LIST_ID = CONFIG['clickup_list_id']

# Canvas to clickup main code
class CanvasToClickUp
  # Retrieves all courses whose start date is in the past, and end date is in the future, or either are nil.
  # @return [Array<String>] all active course IDs
  def active_courses
    graphql = "query { allCourses { id, name, term { id, startAt, endAt } } }"

    courses = send_graphql(graphql)['data']['allCourses']

    courses.select! do |course|
      course['term']['startAt'].nil? || (Time.parse(course['term']['startAt']) < Time.now && Time.parse(course['term']['endAt']) > Time.now)
    end

    courses.map { |course| course['id'] }
  end

  # Returns incomplete assignments for the provided courses.
  # These are simply assignments with no submissions.
  # @param courses [Array<String>] course IDs to retrieve incomplete assignments for
  # @return [Hash<String->Array<Assignment>>] a mapping of course names to assignments
  def assignments(courses)
    course_bodies = []

    courses.each_with_index do |course_id, index|
      course_bodies << "c#{index}: course(id: \"#{course_id}\") { name, assignmentsConnection { nodes { name, description, dueAt, htmlUrl, submissionTypes, submissionsConnection { nodes { grade } } } } }"
    end

    data = send_graphql("query { #{course_bodies.join(' ')} }")['data']

    assignments = {}

    data.each do |_, nodes|
      course_assignments = []
      nodes['assignmentsConnection']['nodes'].each { |node| course_assignments.push Assignment.new(node) }
      assignments[nodes['name']] = course_assignments
    end

    assignments
  end

  # Gets a list of tasks from ClickUp
  # @return [Array<Task>] list of tasks
  def tasks
    # Get the current task list from clickup
    task_response = JSON.parse(RestClient.get("#{BASE_URLS[:clickup]}/list/#{CLICKUP_LIST_ID}/task?include_closed=true", Authorization: TOKENS[:clickup]))

    task_response['tasks'].map { |task| Task.new(task) }
  end

  # Retrieves the custom fields from ClickUp
  # @return [Array<CustomField>] list of custom fields
  def custom_fields
    # Get custom fields from ClickUp
    fields = JSON.parse(RestClient.get("#{BASE_URLS[:clickup]}/list/#{CLICKUP_LIST_ID}/field", Authorization: TOKENS[:clickup]))

    fields['fields'].map { |field| CustomField.new(field) }
  end

  # @return [Hash] The data
  def send_graphql(query)
    url = URI(BASE_URLS[:canvas_graphql])

    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["Authorization"] = TOKENS[:canvas]
    request["Content-Type"] = "application/json"
    request.body = "{\"query\":#{query.to_json},\"variables\":{}}"

    response = https.request(request)
    JSON.parse(response.read_body)
  end

  def update_custom_field(id, data)
    # https://api.clickup.com/api/v2/task/task_id/field/field_id/
  end
end

TERMINAL_WIDTH = `tput cols`.to_i

def print_to_console(message)
  if message.length < TERMINAL_WIDTH
    # Pad the message to the terminal width
    message += ' ' * (TERMINAL_WIDTH - message.length)
  end

  print message
end


print_to_console "[0/4] Fetching data!"

info = CanvasToClickUp.new

print_to_console "\r[1/4] Retrieving active courses."
courses = info.active_courses

print_to_console "\r[2/4] Retrieving assignments."
all_assignments = info.assignments(courses)

puts "\rDetected #{all_assignments.values.flatten.length} assignments in #{courses.length} courses."

print_to_console "\r[3/4] Retrieving tasks."
clickup = info.tasks

print_to_console "\r[4/4] Retrieving custom fields."
fields = info.custom_fields

puts "\rAll data retrieved! Starting to process."

created = 0
updated = 0
nothing = 0
index = 0

TASKS = all_assignments.values.flatten.length

print_to_console "\r[0/#{TASKS}] Processing tasks."

# @type assignments [List<Assignment>]
all_assignments.each do |course_name, assignments|
  class_name = course_name.class_name

  # @type assignment [Assignment]
  assignments.each do |assignment|
    index += 1
    print_to_console "\r[#{index}/#{TASKS}] Processing #{assignment.name} in #{class_name}"

    clickup_task = clickup.find { |item| item.canvas_link == assignment.url }
    if clickup_task
      print_to_console "\r[#{index}/#{TASKS}] Processing #{assignment.name} in #{class_name} with ClickUp task ID #{clickup_task.id}"

      update = {}
      update[:name] = assignment.name unless assignment.name == clickup_task.name

      add = assignment.due_date.nil? ? nil : assignment.due_date.to_i * 1000
      cdd = clickup_task.due_date.nil? ? nil : clickup_task.due_date.to_i * 1000
      unless add == cdd
        # puts "  !Due date changed from #{clickup_task.due_date} to #{assignment.due_date}"
        update[:due_date] = add
        update[:due_date_time] = true
      end
      update[:description] = assignment.description unless assignment.description.to_s.chomp == clickup_task.description.to_s.chomp
      unless assignment.status.downcase == clickup_task.status.downcase
        update[:status] = assignment.status
        # puts "  !Status changed from #{clickup_task.status.downcase} to #{assignment.status.downcase}"
      end
      if assignment.graded? && assignment.grade != clickup_task.grade
        #update[:grade] = assignment.grade
        #puts "  !Grade changed from #{clickup_task.grade} to #{assignment.grade}"
      end

      if update.empty?
        nothing += 1
        next
      end

      print_to_console "\r[#{index}/#{TASKS}] Updating in ClickUp with the following changes: #{update.map { |k, _v| k.to_s }.join(', ')}"
      print_to_console "\n[#{index}/#{TASKS}] Processing #{assignment.name} in #{class_name} with ClickUp task ID #{clickup_task.id}"

      ClickUp.update_task(clickup_task.id, update)

      updated += 1
    else
      print_to_console "\r[#{index}/#{TASKS}] Creating task."
      print_to_console "\n[#{index}/#{TASKS}] Processing #{assignment.name} in #{class_name}."

      # Handle custom fields
      custom_fields = []
      fields.each do |field|
        # noinspection RubyCaseWithoutElseBlockInspection
        case field.name
        when "Canvas Link"
          custom_fields << {
            id: field.id,
            value: assignment.url
          }
          next
        when "Class"
          custom_fields << {
            id: field.id,
            value: field.dropdown_option(class_name).index
          }
          next
        end
      end

      body = {
        "name": assignment.name,
        "description": assignment.description,
        "status": "To Do",
        "due_date": assignment.due_date.to_i * 1000,
        "due_date_time": true,
        "custom_fields": custom_fields
      }

      ClickUp.create_task(body)

      created += 1
    end
  end

  # puts response
end

print_to_console "\rFinished processing #{index} tasks."
puts "\n"

puts "Created: #{created}"
puts "Updated: #{updated}"
puts "No Changes: #{nothing}"
