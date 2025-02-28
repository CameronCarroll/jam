require "json"
require "option_parser"
require "./llamaclient"

CONFIG_FILE = ".jam_config.json"
MODEL = "phi4:latest"




class Workspace
    property name : String
    property projects : Array(Project)

    def initialize(@name : String)
        @name = name
        @projects = [] of Project
    end

    def add_project(project : Project)
        @projects << project
    end

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

    def context_dump_all_projects : String
        superbigstring = String.new
        @projects.each do |project|
            superbigstring += project.name
            superbigstring += project.description
        end
        return superbigstring
    end

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

    def get_project_by_index(index : Int) : Project?
      return @projects[index]
    end

    def remove_project_by_index(index : Int)
      @projects.delete_at(index)
    end

end

class Project
    property name : String
    property description : String

    def initialize(
        @name : String,
        @description : String
    )
    end
end

unless File.exists?(CONFIG_FILE)
    File.open(CONFIG_FILE, "w") do |file|
        file.print("[]")
    end
end

workspace = Workspace.new("LLM Project")
# Load config file and projects into workspace
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
                    workspace.add_project(project)
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

#--------------------------------------------
projectdump = false
chatloop = false
projectedit = false

parser = OptionParser.new do |parser|
  parser.banner = "Usage: jam [command]"
  parser.on("LMprojectdump", "Dump all projects into context") do
    projectdump = true
  end
  parser.on("LMchatloop", "Enter into a blank chat with default model") do
    chatloop = true
  end
  parser.on("projects", "Make updates to project entries") do
    projectedit = true
    parser.banner = "Usage: jam projects [argument]"
    parser.on("-n NAME", "--new NAME", "Add a name for the project entry") { |_name| name = _name}
  end
end

parser.parse

if projectdump
  prompt = String.new
  system_prompt = "You are project management / personal assistant AI expert system program. You are being provided with a full list of all active projects in your database. You have been tasked with finding information on the 'Project Quantum' activities. If you find something relevant, include <RELEVANT> in the results. If you don't find anything relevant, include the token <NULL>."
  prompt += system_prompt
  prompt += workspace.context_dump_all_projects
  if prompt == ""
    puts "no prompt"
  else
    result = LlamaClient.send_text(prompt, MODEL)
    puts result
  end
else
  puts "no action"
end

if chatloop
  context = String.new
  loop do
    puts "=> "
    input = gets
    if input.is_a?(String)
      case input
      when ""
        next
      when "exit"
        break
      else
        context += input
        model_response = LlamaClient.send_text(context, MODEL)
      end
      if model_response.is_a?(String)
        puts model_response
        context += model_response
      else
        puts "Model error"
      end
    else
      puts "Input error"
    end
  end
end

if projectedit
  puts "Entering project data edit mode."
  loop do
    puts "======= Project Edit Mode ======="
    puts "Choices: (Enter a number)"
    puts "0. Print out all project entries for reference"
    puts "1. Create new project entry"
    puts "2. Edit an existing project entry"
    puts "3. Delete an existing project entry"
    puts "'exit' to quit"
    if user_response = gets
      user_response = user_response.chomp
    else
      puts "No response??"
      break
    end
    case user_response
    when "0"
      puts workspace.dump_projects_for_human
    when "1"
      puts "Creating a new project entry..."
      puts "What is the project name?"
      project_name = gets
      if project_name.is_a?(String)
        if project_name == ""
          puts "Bad name"
          break
        end
        puts "OK now drop in a project description."
        project_description = gets
        if project_description.is_a?(String)
          puts "OK I'm making a new project entry with the name and description provided."
          newproject = Project.new(project_name, project_description)
          workspace.add_project(newproject)
          workspace.save_config
        else
          puts "Bad description"
          break
        end
      else
        puts "Bad name"
      end
    when "2" # Edit project
      puts "Editing existing project entry..."
      puts workspace.dump_projects_for_human # Show projects for reference
      puts "Enter the number of the project you want to edit:"
      project_index_str = gets
      if project_index_str.is_a?(String)
        begin
          project_index = project_index_str.chomp.to_i
          project_to_edit = workspace.get_project_by_index(project_index)
          if project_to_edit
            puts "You selected project ##{project_index}:"
            puts "Current name: #{project_to_edit.name}"
            puts "Current description: #{project_to_edit.description}"

            puts "Enter new name (or leave blank to keep current):"
            if new_name = gets
              new_name = new_name.chomp
            else
              puts "Bad name"
              break
            end
            puts "Enter new description (or leave blank to keep current):"
            if new_description = gets
              new_description = new_description.chomp
            else
              puts "Bad description"
              break
            end

            project_to_edit.name = new_name unless new_name.empty?
            project_to_edit.description = new_description unless new_description.empty?

            workspace.save_config
            puts "Project ##{project_index} updated."
          else
            puts "Invalid project number."
          end
        rescue e
          puts "Invalid input for project number."
        end
      else
        puts "Invalid input for project number."
      end
    when "3"
      puts "Deleting existing project entry..."
      puts workspace.dump_projects_for_human # Show projects for reference
      puts "Enter the number of the project you want to DELETE:"
      project_index_str = gets
      if project_index_str.is_a?(String)
        begin
          project_index = project_index_str.chomp.to_i
          project_to_delete = workspace.get_project_by_index(project_index)
          if project_to_delete
            puts "You are about to DELETE project ##{project_index}:"
            puts "Name: #{project_to_delete.name}"
            puts "Description: #{project_to_delete.description}"
            puts "Are you sure? (yes/no)"
            if confirmation = gets
              formatted_confirmation = confirmation.chomp.downcase
            else
              puts "Bad confirmation"
              break
            end
            if formatted_confirmation == "yes"
              workspace.remove_project_by_index(project_index)
              workspace.save_config
              puts "Project ##{project_index} deleted."
            else
              puts "Deletion cancelled."
            end
          else
            puts "Invalid project number."
          end
        rescue e
          puts "Invalid input for project number."
        end
      else
        puts "Invalid input for project number."
      end
    when "exit"
      break
    else
      puts "Really terrible choice"
    end
  end
end