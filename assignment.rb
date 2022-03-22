# frozen_string_literal: true

require 'time'

# A wrapper for the assignment JSON from Canvas
class Assignment
  def initialize(data)
    @data = data
  end

  # get the assignment name
  def name
    @data['name']
  end

  # A textual representation of the description
  # @return [String] the description
  def description
    return '' if @data['description'].nil?

    Nokogiri.parse(@data['description'].gsub("&nbsp;", " ")).text.strip
  end

  # @return [String] the URL to access the assignment
  def url
    # noinspection HttpUrlsUsage I AM FIXING IT
    @data['htmlUrl'].gsub("http://", "https://")
  end

  # @return [Time, nil] the due date, or nil if there is no due date
  def due_date
    return nil if @data['dueAt'].nil?

    Time.parse @data['dueAt']
  end

  # The submission types for this assignment
  # @return [Array<String>] the submission types
  def types
    @data['submissionTypes']
  end

  # Returns the submission nodes for this assignment
  # @return [Array] an array of Submission objects
  def submissions
    @data['submissionsConnection']['nodes']
  end

  # Returns if the assignment has a submission and the submission grade is not nil
  # @return [Boolean] true if the assignment is graded
  def graded?
    return false if submissions.empty?

    submissions[0]['grade'] != nil
  end

  def grade
    return nil unless graded?

    submissions[0]['grade']
  end

  # Return if this assignment has any submissions
  # @return [Boolean] true if the assignment has submissions
  def submitted?
    !submissions.empty?
  end

  def status
    return "Graded" if graded?
    return "Submitted" if submitted?

    "To Do"
  end
end
