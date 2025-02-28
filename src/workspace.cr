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
      project_data_to_save = [] of Hash(String, String)
      @projects.each do |project|
        project_data_to_save << {
            "name" => project.name,
            "description" => project.description,
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
  end