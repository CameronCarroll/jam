# Jam - Crystal Project Guidelines

## Build/Test Commands
- Build: `crystal build src/jam.cr`
- Run: `crystal src/jam.cr`
- Test all specs: `crystal spec`
- Run a single test: `crystal spec spec/node_spec.cr`
- Format code: `crystal tool format`

## Code Style Guidelines
- **Imports**: Group standard library imports first, then external modules, then local imports
- **Naming**: Classes use PascalCase; methods/variables use snake_case
- **Documentation**: Use doc comments above class/method declarations
- **Error Handling**: Use custom error classes that inherit from `Error`
- **Types**: Always specify types for method parameters and properties
- **Formatting**: 2-space indentation, no trailing whitespace
- **Properties**: Use Crystal's property syntax for class attributes
- **Testing**: Use spec format with describe/it blocks
- **Parameters**: Use named parameters in constructors/methods with multiple arguments

## Project Structure
- `src/`: Main source code
- `spec/`: Test files
- `bin/`: Executable scripts
- `lib/`: External libraries