# Represents a single project with a name and description.
#
# A project is anything that takes more than two steps.
# If it takes one step, it's a task, and we would just do it.
class Project
    # @property name [String]
    # Returns the name of the project.
    property name : String
    # @property description [String]
    # Returns the description of the project.
    property description : String
  
    # Initializes a new Project with a name and description.
    #
    # @param name [String] The name of the project.
    # @param description [String] The description of the project.
    def initialize(
        @name : String,
        @description : String
    )
    end
  end