# Represents a workspace that contains multiple projects.
#
# A workspace is the top-level container for projects and handles
# persistence, loading, and project management operations.
#
# Example:
#
# ```crystal
# workspace = Workspace.new("My Workspace")
# workspace.add_project(Project.new("Project A", "Description"))
# workspace.save_config
# ```
class Workspace
    # @property name [String]
    # Returns the name of the workspace.
    property name : String
  
    # @property projects [Array(Project)]
    # Returns the list of projects within the workspace.
    property projects : Array(Project)
  
    # Initializes a new Workspace with a given name.
    #
    # @param name [String] The name of the workspace.
    def initialize(@name : String)
      @name = name
      @projects = [] of Project
    end
  
    # Adds a project to the workspace.
    #
    # @param project [Project] The project to be added.
    def add_project(project : Project)
      @projects << project
    end
  
    # Saves the workspace configuration to a JSON file.
    #
    # The configuration includes the name and description of each project
    # within the workspace. The data is saved to the file specified by `CONFIG_FILE`.
    #
    # @see CONFIG_FILE
    def save_config
      project_data_to_save = [] of Hash(String, String | Array(String))
      @projects.each do |project|
        project_data_to_save << {
            "id" => project.id,
            "name" => project.name,
            "description" => project.description,
            "predecessors" => project.predecessors,
            "successors" => project.successors
        }
      end
      jason_content = project_data_to_save.to_json
  
      begin
        File.write(CONFIG_FILE, jason_content)
        puts "Workspace config saved to config file #{CONFIG_FILE}"
      rescue e : File::Error
        puts "Error saving configuration: #{e}"
      end
    end
  
    # Dumps the context of all projects into a single string.
    #
    # This method concatenates the name and description of each project
    # in the workspace. This can be used for providing context to language models.
    #
    # @return [String] A string containing the combined project names and descriptions.
    def dump_projects_for_llm : String
      superbigstring = String.new
      @projects.each do |project|
        superbigstring += project.name
        superbigstring += project.description
      end
      return superbigstring
    end
  
    # Dumps the list of projects in a human-readable format.
    #
    # This method formats the project list with indices, names, and descriptions,
    # making it suitable for display in the command line interface.
    #
    # @return [String] A formatted string representing the list of projects.
    def dump_projects_for_human : String
      superbigstring = String.new
      superbigstring += "Project list:\n"
      superbigstring += "-------------\n"
      @projects.each.with_index do |project, index|
        superbigstring += "##{index}:\n"
        superbigstring += project.name
        superbigstring += "\n"
        superbigstring += project.description
        superbigstring += "\n-------------\n"
      end
      return superbigstring
    end
  
    # Retrieves a project from the workspace by its index.
    # Corresponds to the index & order user sees, @see dump_projects_for_human
    #
    # @param index [Int] The index of the project to retrieve.
    # @return [Project?] The project at the given index, or `nil` if the index is invalid.
    def get_project_by_index(index : Int) : Project?
      return @projects[index]
    end
  
    # Removes a project from the workspace by its index.
    #
    # @param index [Int] The index of the project to remove.
    def remove_project_by_index(index : Int)
      @projects.delete_at(index)
    end

    # Reads config file, parses the JSON and loads workspace with project data.
    #
    # @param config_path [String] Path to the JSON configuration file
    def read_config(config_path) : Nil
      begin
        jason_content = File.read(CONFIG_FILE)
        projects_data = Array(Hash(String, String)).from_json(jason_content)
        if projects_data.is_a?(Array)
          projects_data.each do |project_hash|
            if project_hash.is_a?(Hash)
              project_name = project_hash["name"]
              project_description = project_hash["description"]
      
              if project_name.is_a?(String)
                project = Project.new(project_name, project_description)
                self.add_project(project)
              else
                puts "Error with project name field."
                puts "Problematic data: #{project_hash}"
              end
            else
              puts "Error with project data hash."
              puts "Problematic data: #{project_hash}"
            end
          end
        else
          puts "Error with JSON data, expected array of projects."
        end
      rescue e : File::Error
        puts "Error reading/parsing JSON file: #{e}"
        puts "Problematic path: #{CONFIG_FILE}"
      end
    end

    # Gets a project by ID from our workspace projects list
    #
    # @param id [String] UUID of the project to reference
    # @return [Project?] Returns project if found or Nil if not found.
    def get_project_by_id(id : String) : Project?
      @projects.find { |project| project.id == id }
    end

    # Create a bidirectional dependency between two projects
    #
    # @param predecessor_id [String] ID of the project to set up as predecessor
    # @param successor_id [String] ID of the project to be set up as succcessor
    # @return [Bool] Returns True on success and False on failure
    def create_dependency(predecessor_id : String, successor_id : String) : Bool
      predecessor = get_project_by_id(predecessor_id)
      successor = get_project_by_id(successor_id)

      return false unless predecessor && successor

      predecessor.add_successor(successor_id)
      successor.add_predecessor(predecessor_id)

      save_config
      return true
    end

    # Remove a bidirectional dependency between two projects
    #
    # @param predecessor_id [String] ID of the predecessor project
    # @param successor_id [String] ID of the succcessor project
    # @return [Bool] Returns True on success and False on failure
    def remove_dependency(predecessor_id : String, successor_id : String) : Bool
      predecessor = get_project_by_id(predecessor_id)
      successor = get_project_by_id(successor_id)
      
      return false unless predecessor && successor
      
      # Remove the bi-directional relationship
      predecessor.remove_successor(successor_id)
      successor.remove_predecessor(predecessor_id)
      
      save_config  # Save changes to config
      return true
    end

    # Get all successors for a given project
    #
    # @param project_id [String] ID of the project to query for
    # @return [Array(Project)] List of successor project objects
    def get_successors(project_id : String) : Array(Project)
      project = get_project_by_id(project_id)
      return [] of Project unless project

      project.successors.compact_map { |id| get_project_by_id(id) }
    end

    # Get all predecessors for a given project
    #
    # @param project_id [String] ID of the project to query for
    # @return [Array(Project)] List of predecessors project objects
    def get_predecessors(project_id : String) : Array(Project)
      project = get_project_by_id(project_id)
      return [] of Project unless project
      
      project.predecessors.compact_map { |id| get_project_by_id(id) }
    end

    # Find the root projects (projects with no predecessors)
    #
    # @return [Array(Project)] List of root project objects
    def get_root_projects : Array(Project)
      @projects.select { |project| project.predecessors.empty? }
    end

    # Find the leaf projects (projects with no successors)
    #
    # @return [Array(Project)] List of leaf project objects
    def get_leaf_projects : Array(Project)
      @projects.select { |project| project.successors.empty? }
    end

    def dump_dependency_graph : String
      result = String.new
      result += "Project Dependency Graph:\n"
      result += "=========================\n\n"
      
      # Process each project
      @projects.each do |project|
        result += "#{project.name} (ID: #{project.id}):\n"
        
        if project.predecessors.empty?
          result += "  Predecessors: None\n"
        else
          result += "  Predecessors:\n"
          project.predecessors.each do |pred_id|
            if pred = get_project_by_id(pred_id)
              result += "    - #{pred.name}\n"
            else
              result += "    - Unknown project (#{pred_id})\n"
            end
          end
        end
        
        if project.successors.empty?
          result += "  Successors: None\n"
        else
          result += "  Successors:\n"
          project.successors.each do |succ_id|
            if succ = get_project_by_id(succ_id)
              result += "    - #{succ.name}\n"
            else
              result += "    - Unknown project (#{succ_id})\n"
            end
          end
        end
        
        result += "\n"
      end
      
      return result
    end
  end