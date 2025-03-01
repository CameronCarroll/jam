# jam
# by ieve, Winter (but it feels like Spring) 2025
# Purpose: Playing around with structured data and LLMs in node management / personal assistant context.

require "json"
require "option_parser"
require "./llamaclient"
require "./workspace"
require "./node"
require "./cli"
require "./planner"

CONFIG_FILE = ".jam_config.json"
MODEL = "phi4:latest"


unless File.exists?(CONFIG_FILE)
  File.open(CONFIG_FILE, "w") do |file|
    file.print("[]")
  end
end

workspace = Workspace.new("LLM Project")
# Load config file and nodes into workspace
workspace.read_config(CONFIG_FILE)

#--------------------------------------------
nodedump = false
chatloop = false
nodeedit = false
execution_plan = false

parser = OptionParser.new do |parser|
parser.banner = "Usage: jam [command]"
parser.on("LMnodedump", "Dump all nodes into context") do
  nodedump = true
end
parser.on("LMchatloop", "Enter into a blank chat with default model") do
  chatloop = true
end
parser.on("nodes", "CLI REPL to make updates to node entries") do
  nodeedit = true
  parser.banner = "Usage: jam nodes [argument]"
  parser.on("-n NAME", "--new NAME", "Add a name for the node entry") { |_name| name = _name}
end
parser.on("plan", "Generate and print an execution plan from the current workspace config") do
  execution_plan = true
end
end

parser.parse

if nodedump
  prompt = String.new
  system_prompt = "You are node management / personal assistant AI expert system program. You are being provided with a full list of all active nodes in your database. You have been tasked with finding information on the 'Project Quantum' activities. If you find something relevant, include <RELEVANT> in the results. If you don't find anything relevant, include the token <NULL>."
  prompt += system_prompt
  prompt += workspace.dump_nodes_for_llm
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

if nodeedit
  cli = ProjectCLI.new(workspace)
  puts "Entering node data edit mode."
  loop do
    puts "======= Project Edit Mode ======="
    puts "Choices: (Enter a number)"
    puts "0. Print out all node entries for reference"
    puts "1. Create new node entry"
    puts "2. Edit an existing node entry"
    puts "3. Delete an existing node entry"
    puts "4. View node dependency graph"
    puts "5. Add relationship between nodes"
    puts "'exit' to quit"
    if user_response = gets
      user_response = user_response.chomp
    else
      puts "No response??"
      break
    end
    case user_response
    when "0"
      puts workspace.dump_nodes_for_human
    when "1" # New node entry
      cli.new_node_entry
    when "2" # Edit node
      cli.edit_node_entry
    when "3" # Delete node entry
      cli.delete_node_entry
    when "4"
      puts Planner.dump_dependency_graph(workspace)
    when "5"
      cli.add_relationship_between_nodes
    when "exit"
      break
    else
      puts "Really terrible choice"
    end
  end
end

if execution_plan
  puts Planner.generate_execution_plan(workspace)
end