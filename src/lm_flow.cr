
# Represents a generic LLM inference operation
#
# Examples are It might be a planning step or a command output step or a reflection step or we might extend it in the future to maybe include data analysis steps or maybe we're calling out to other tools and other techniques that are in just the LM in the middle. So basically just a chunk of some bigger processes. (soft music)
class LMFlow
    # So what does a flow do, and what information does it have?

    # First of all, it has a model with some parameters. Maybe we want to run certain flows with Command, but other flows we want to run with our biggest thinking model available. 

    # I think the input is the output from our previous flow - a string.
    # The output is also a string.

    # It also needs access to the workspace state, so that it can assemble all those little pieces of context.
    # It needs to know the output file.
end