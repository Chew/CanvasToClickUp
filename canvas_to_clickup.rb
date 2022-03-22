# frozen_string_literal: true

require 'json'
require "net/http"
require 'nokogiri'
require 'rest-client'
require 'yaml'
require "uri"

require_relative './assignment'
require_relative './custom_field'
require_relative './task'

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
      body = "c#{index}: course(id: \"#{course_id}\") { name, assignmentsConnection { nodes { name, description, dueAt, htmlUrl, submissionTypes, submissionsConnection { nodes { grade } } } } }"
      course_bodies << body
    end

    data = send_graphql("query { #{course_bodies.join(' ')} }")['data']

    assignments = {}

    data.each do |_, nodes|
      course_assignments = []
      nodes['assignmentsConnection']['nodes'].each do |node|
        course_assignments.push Assignment.new(node)
      end
      assignments[nodes['name']] = course_assignments
    end

    assignments
  end

  # Gets the class name
  # @return [String] the class name
  def class_name
    # Convert "2222-COMS-2302-021-PROFESSIONAL TECHNICAL COMM" to "COMS 2302"
    @data['context_name']
  end

  # Gets a list of tasks to-do from Canvas
  # @return [Array<Assignment>] list of tasks to-do
  def todo
    list = JSON.parse(RestClient.get("#{BASE_URLS[:canvas]}/users/self/todo?per_page=100", Authorization: TOKENS[:canvas]))
    list.map { |task| Assignment.new(task) }
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
    body = response.read_body
    JSON.parse(body)
  end
end

puts "Fetching data!"

info = CanvasToClickUp.new

courses = info.active_courses
puts "Active courses: #{courses}"

all_assignments = info.assignments(courses)

puts "There are #{all_assignments.values.flatten.length} assignments in #{courses.length} courses. Wow!"
# puts "Assignments: #{assignments}"

clickup = info.tasks
fields = info.custom_fields

created = 0
updated = 0
nothing = 0

# @type assignments [List<Assignment>]
all_assignments.each do |course_name, assignments|
  class_name = if course_name.start_with? "2222" # temporary hack
                 course_name.split('-')[1..2].join(' ')
               elsif course_name.start_with? "CSE 1310"
                 "CSE 1310"
               end

  # @type assignment [Assignment]
  assignments.each do |assignment|
    puts "Detected #{assignment.name} in #{class_name}"

    clickup_task = clickup.find { |item| item.canvas_link == assignment.url }
    if clickup_task
      puts "  Assignment #{assignment.name} already exists in ClickUp with ID #{clickup_task.id}"

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

      if update.empty?
        nothing += 1
        next
      end

      puts "  Updating #{assignment.name} in ClickUp with the following changes: #{update.map { |k, _v| k.to_s }.join(', ')}"

      response = JSON.parse RestClient.put("#{BASE_URLS[:clickup]}/task/#{clickup_task.id}",
                                           update.to_json,
                                           Authorization: TOKENS[:clickup],
                                           content_type: :json,
                                           accept: :json)

      updated += 1
    else
      puts "  Creating task #{assignment.name}"

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

      response = JSON.parse RestClient.post("#{BASE_URLS[:clickup]}/list/#{CLICKUP_LIST_ID}/task",
                                            body.to_json,
                                            Authorization: TOKENS[:clickup],
                                            content_type: :json,
                                            accept: :json)

      created += 1
    end
  end

  # puts response
end

puts "  Done!"

puts "Created: #{created}"
puts "Updated: #{updated}"
puts "No Changes: #{nothing}"
