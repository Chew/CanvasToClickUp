# frozen_string_literal: true

# A wrapper for the custom field JSON from ClickUp
class CustomField
  def initialize(data)
    @data = data
  end

  def id
    @data['id']
  end

  def name
    @data['name']
  end

  def type
    @data['type']
  end

  def dropdown_options
    @data['type_config']['options'].map { |option| DropdownOption.new(option) }
  end

  # @return [DropdownOption]
  def dropdown_option(name)
    dropdown_options.find { |option| option.name == name }
  end

  # Dropdown option
  class DropdownOption
    def initialize(data)
      @data = data
    end

    def id
      @data['id']
    end

    def name
      @data['name']
    end

    def index
      @data['orderindex']
    end
  end
end
