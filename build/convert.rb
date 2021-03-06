require 'fileutils'

# Replace AMD definitions to CommonJS.

GLOBALS = <<GLOBALS
require.define 'jquery', (require, module, exports, __dirname, __filename) -> module.exports = $
require.define 'underscore', (require, module, exports, __dirname, __filename) -> module.exports = _
require.define 'backbone', (require, module, exports, __dirname, __filename) -> module.exports = Backbone

GLOBALS

def make_module_definition(name, source)
  "require.define #{name}, (require, module, exports, __dirname, __filename) ->#{source}"
end

def convert_one(raw_modules = '', raw_module_names = '')
  unless raw_modules
    return ''
  end

  # "'lib/utils' 'models/model', 'models/collection'"
  # => ['lib/utils', 'models/model', 'models/collection']
  modules = raw_modules.strip.split(' ').map do |mdl|
    mdl.gsub(',', '')
  end

  # utils, Model, Collection
  # => ['utils', 'Model', 'Collection']
  module_names = raw_module_names.strip.split(',').map(&:strip)

  definitions_arr = []

  module_names.each_with_index do |module_name, index|
    # "  utils = require 'lib/utils'"
    definitions_arr << "  #{module_name} = require #{modules[index]}"
  end

  "\n" + definitions_arr.join("\n") + "\n"
end

def convert_modules(string)
  # define 'name', ['req1', 'req2', 'req3'], (req1, req2, req3) ->
  re = /(define ('.*'),(?: \[([,\s\w\/_']*)\],)? (?:\(([\s\w,\$_]*)\) )?->)/
  str = String.new(string)

  # Copy string because we're using mutable replace method.
  # Scan it for regexp then.
  str.scan(re).each do |match|
    src = match[0]  # The whole shit.
    name = match[1]  # module name.
    raw_modules = match[2]  # (optional) list of module paths.
    raw_module_names = match[3]  # (optional) list of module names.
    definition = convert_one(raw_modules, raw_module_names)
    str[src] = make_module_definition(name, definition)
  end

  str
end

def strict(string)
  # Replace all 'use strict's with one strict at the top of file.
  "'use strict'\n\n" + GLOBALS + string.gsub(/\s*'use strict'/, '')
end

def convert_exports(string)
  File.open('__tmp.coffee', 'w') { |file| file.write(string) }
  output = `coffee convert_exports.coffee < __tmp.coffee`
  FileUtils.rm('__tmp.coffee')
  output
end

def convert(string)
  strict(convert_exports(convert_modules(string)))
end

if __FILE__ == $0
  puts convert(STDIN.read)
end
