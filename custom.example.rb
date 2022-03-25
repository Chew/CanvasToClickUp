# frozen_string_literal: true

# This file is used to modify Ruby specific settings.
# For now, this is just a way to clean up the class name.
# To edit this, copy it over to custom.rb and replace any `self` with your own custom return value.
# Keep in mind that `self` is the current value of the string, so you can use it to modify the string.
# You also do not need to do `self.method`, you can just do `method`.
class String
  # Converts the name of the class to a more readable format.
  def class_name
    self
  end
end
