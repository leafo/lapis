# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lapis is a web framework for Lua and MoonScript supporting OpenResty and lua-http servers. It provides a full-featured web application framework with database models, routing, HTML generation, validation, sessions, and more.

## Key Development Commands

### Building
- `make build` - Compiles all MoonScript (.moon) files to Lua (.lua)
- `moonc lapis` - Compile only the lapis directory
- `make local` - Build and install locally

### Testing
- `make test` - Run all test suites (requires databases)
- `busted spec` - Run basic Lua tests
- `busted spec_postgres` - Run PostgreSQL integration tests  
- `busted spec_mysql` - Run MySQL integration tests
- `busted spec_openresty` - Run OpenResty integration tests
- `busted spec_cqueues` - Run cqueues/lua-http tests

### Database Setup
- `make test_db` - Create PostgreSQL test database
- `make mysql_test_db` - Create MySQL test database

### Linting
- `make lint` - Run MoonScript linter on all .moon files
- `moonc -l <file>` - Lint specific MoonScript file

### Cleanup
- `make clean` - Remove all compiled .lua files

## Architecture

### Core Components

**Application Layer** (`lapis/application.moon`):
- Main application class and request handling
- Route definition and dispatching
- Before/after filters and middleware
- Action loading and execution

**Router** (`lapis/router.moon`):
- URL pattern matching and route compilation
- Parameter extraction from URLs
- Route precedence handling

**Database Layer** (`lapis/db/`):
- Database-agnostic model system
- Support for PostgreSQL, MySQL, and SQLite
- Schema management and migrations
- Model relations and preloading

**HTML Generation** (`lapis/html.moon`):
- DSL for generating HTML in Lua/MoonScript
- Widget system for reusable components
- HTML escaping and security

**Configuration** (`lapis/config.moon`):
- Environment-based configuration
- Database connection settings
- Server and application settings

**Validation** (`lapis/validate.moon`):
- Input validation functions
- Form validation patterns
- Type checking and sanitization

**Validation Types** (`lapis/validate/types.moon`):
- Extended type system built on tableshape for parameter validation
- Specialized types for web applications (db_id, db_enum, file_upload)
- Text validation with UTF-8 support (cleaned_text, valid_text, trimmed_text)
- Complex parameter validation (params_shape, params_array, params_map)
- Error aggregation and transformation utilities

**Session Management** (`lapis/session.moon`):
- Cookie-based session handling
- Session encoding/decoding
- CSRF protection

**Flow System** (`lapis/flow.moon`):
- Object wrapper that forwards method calls to wrapped objects
- Encapsulates functionality within Flow class scope
- Provides memoization utilities for caching method results
- Supports extensible flow objects with property assignment control

### File Structure

- `lapis/` - Core framework code
- `lapis/cmd/` - Command-line tools and templates
- `lapis/db/` - Database abstraction and models
- `lapis/nginx/` - OpenResty/Nginx integration
- `lapis/util/` - Utility functions
- `lapis/spec/` - Testing utilities
- `spec/` - Test suites
- `docs/` - Documentation files

### MoonScript vs Lua

This codebase uses MoonScript (.moon files) as the primary language, which compiles to Lua (.lua files). The compiled Lua code is checked into the repository so that the framework can be installed without requiring a MoonScript compiler. When working with the code:

- Always edit .moon files, not .lua files
- Run `make build` after editing .moon files to compile MoonScript to Lua
- The .lua files are generated and should not be edited directly
- Both .moon and .lua files are committed to the repository

### Database Model System

The framework supports multiple databases through a unified model interface:

- Models automatically detect database type from config
- `lapis/db/model.moon` acts as a dispatcher to specific database implementations
- Database-specific models in `lapis/db/postgres/`, `lapis/db/mysql/`, `lapis/db/sqlite/`
- Relations system supports belongs_to, has_many, has_one patterns

### Server Integration

Lapis supports multiple server backends:

- OpenResty (default) - High performance Nginx + LuaJIT
- lua-http with cqueues - Pure Lua HTTP server
- Configuration determines which backend to use

## Development Environment

The project uses LuaRocks for dependency management. Key dependencies include:
- MoonScript (for compilation)
- Busted (for testing)
- lua-cjson (JSON handling)
- pgmoon (PostgreSQL driver)
- Various Lua utilities

### Rockspec Management

The `lapis-dev-1.rockspec` file defines the LuaRocks package specification for Lapis. This file contains:

- **Dependencies**: External Lua packages required by Lapis
- **Build modules**: Complete mapping of all Lua modules in the framework
- **Install configuration**: Binary files and installation settings

**When to update the rockspec:**
- Adding new `.lua` files to the `lapis/` directory structure
- Removing existing `.lua` files from the framework
- Adding new external dependencies to the project
- Changing the binary installation configuration

The `build.modules` section must be manually maintained to include all `.lua` files that should be installed with the package. When adding new MoonScript files that compile to Lua, the corresponding `.lua` file path must be added to this section.

When making changes, ensure all test suites pass before committing.

## Code Documentation Style

### LuaCATS Annotations

When adding type annotations to the codebase, follow these conventions consistent with the existing patterns in `lapis/util.moon`:

**Function Annotations:**
- Use `---` prefix for all annotation lines
- Place annotations directly above the function definition
- Include brief function description on first line
- Use `@param` for parameters with type and description
- Use `@return` for return values with type and optional description
- Mark unused return values with `@nodiscard` if appropriate

```moonscript
---URL decode a string
---@param str string
---@return string
unescape = (str) -> url.unescape str
```

**Parameter Types:**
- Use basic Lua types: `string`, `number`, `boolean`, `table`, `function`, `nil`
- Use `string|number` for union types
- Use `string?` for optional parameters
- Use `table[]` for arrays
- Use `any` for untyped values
- Use `userdata` for external objects (like date objects)

**Table Parameters:**
- For complex table parameters, document fields with nested `@param` entries
- Use descriptive field names in the format `@param parts.field type description`

```moonscript
---Build a URL from component parts
---@param parts table URL components table
---@param parts.path? string URL path
---@param parts.query? string Query string
---@param parts.fragment? string URL fragment
---@param parts.host? string Host name
---@param parts.port? string|number Port number
---@param parts.scheme? string URL scheme (http, https, etc.)
---@return string
build_url = (parts) ->
```

**Return Values:**
- Document all return values, including success/failure booleans
- Use `table|nil` for functions that may return nil
- For multiple return values, document each on separate `@return` lines

```moonscript
---Calculate the difference between two dates
---@param later userdata|string Later date object or string
---@param sooner userdata|string Earlier date object or string
---@return table time_diff Time units (years, days, hours, minutes, seconds)
---@return boolean success Always true
date_diff = (later, sooner) ->
```

**Style Guidelines:**
- Keep descriptions concise but informative
- Use consistent terminology throughout the codebase
- Include units or formats in descriptions when relevant
- Document default values in parameter descriptions
- Use present tense for function descriptions
- Avoid redundant information in descriptions
