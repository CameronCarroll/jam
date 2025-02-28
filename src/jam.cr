# jam
# by ieve, Winter (but it feels like Spring) 2025
# Purpose: Playing around with structured data and LLMs in project management / personal assistant context.

require "json"
require "option_parser"
require "./llamaclient"
require "./workspace"
require "./project"
require "./cli"

CONFIG_FILE = ".jam_config.json"
MODEL = "phi4:latest"


unless File.exists?(CONFIG_FILE)
  File.open(CONFIG_FILE, "w") do |file|
    file.print("[]")
  end
end

workspace = Workspace.new("LLM Project")
# Load config file and projects into workspace
workspace.read_config(CONFIG_FILE)

#--------------------------------------------
projectdump = false
chatloop = false
projectedit = false
execution_plan = false

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
parser.on("plan", "Generate an execution plan from the current workspace config") do
  execution_plan = true
end
end

parser.parse

if projectdump
  prompt = String.new
  system_prompt = "You are project management / personal assistant AI expert system program. You are being provided with a full list of all active projects in your database. You have been tasked with finding information on the 'Project Quantum' activities. If you find something relevant, include <RELEVANT> in the results. If you don't find anything relevant, include the token <NULL>."
  prompt += system_prompt
  prompt += workspace.dump_projects_for_llm
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
  cli = ProjectCLI.new(workspace)
  puts "Entering project data edit mode."
  loop do
    puts "======= Project Edit Mode ======="
    puts "Choices: (Enter a number)"
    puts "0. Print out all project entries for reference"
    puts "1. Create new project entry"
    puts "2. Edit an existing project entry"
    puts "3. Delete an existing project entry"
    puts "4. View project dependency graph"
    puts "5. Add relationship between projects"
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
    when "1" # New project entry
      cli.new_project_entry
    when "2" # Edit project
      cli.edit_project_entry
    when "3" # Delete project entry
      cli.delete_project_entry
    when "4"
      puts workspace.dump_dependency_graph
    when "5"
      cli.add_relationship_between_projects
    when "exit"
      break
    else
      puts "Really terrible choice"
    end
  end
end

if execution_plan
  puts workspace.generate_execution_plan
end