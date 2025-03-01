require "uuid"

# Represents a single project with a name and description.
#
# A project is anything that takes more than two steps.
# If it takes one step, it's a task, and we would just do it.
class Project
    # @property id [String]
    # Unique ID for internal references
    property id : String

    # @property name [String]
    # Set/return the name of the project.
    property name : String

    # @property description [String]
    # Set/return the description of the project.
    property description : String

    # @property predecessors [Array(String)]
    # Set/return a list of predecessor projects
    # (ie, projects that must be completed before this one can start)
    property predecessors : Array(String)

    # @property successors : [Array(String)]
    # Set/return a list of successor projects
    # (ie, projects that cannot start until this one is finished)
    property successors : Array(String)

    # @property requirement_ids : [Array(String)]
    # Set/return a list of requirement IDs associated with this project/task
    property requirement_ids : Array(String)

    # @property goal_ids : [Array(String)]
    # Set/return a list of goal IDs associated with this project/task
    property goal_ids : Array(String)

    # Initializes a new Project with a name and description.
    #
    # @param name [String] The name of the project.
    # @param description [String] The description of the project.
    def initialize(
        @name : String,
        @description : String,
        @id : String = UUID.random.to_s,
        @predecessors = [] of String,
        @successors = [] of String,
        @requirement_ids = [] of String,
        @goal_ids = [] of String
    )
    end

    # Associates a predecessor to this project
    #
    # @param project_id [String] UUID for the project to be added as predecessor
    def add_predecessor(project_id : String)
        @predecessors << project_id unless @predecessors.includes?(project_id)
    end

    # Removes a predecessor task from this project's associations
    #
    # @param project_id [String] UUID for the project to be removed as predecessor
    def remove_predecessor(project_id : String)
        @predecessors.delete(project_id)
    end

    # Associates a successor to this project
    #
    # @param project_id [String] UUID for the project to be added as successor
    def add_successor(project_id : String)
        @successors << project_id unless @successors.includes?(project_id)
    end

    # Removes a successor task from this project's associations
    #
    # @param project_id [String] UUID for the project to be removed as successor
    def remove_successor(project_id : String)
        @successors.delete(project_id)
    end

    # Associates a requirement ID to this project
    #
    # @param project_id [String] UUID for the project to be added as requirement
    def add_requirement(project_id : String)
        @requirement_ids << project_id unless @requirement_ids.includes?(project_id)
    end

    # Removes a requirement ID from this project's associations
    #
    # @param project_id [String] UUID for the project to be removed as requirement
    def remove_requirement(project_id : String)
        @requirement_ids.delete(project_id)
    end

    # Associates a goal ID to this project
    #
    # @param project_id [String] UUID for the project to be added as goal
    def add_goal(project_id : String)
        @goal_ids << project_id unless @goal_ids.includes?(project_id)
    end

    # Removes a goal ID from this project's associations
    #
    # @param project_id [String] UUID for the project to be removed as goal
    def remove_goal(project_id : String)
        @goal_ids.delete(project_id)
    end
  end