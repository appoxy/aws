# require_relative was introduced in 1.9.2. This makes it
# available to younger rubies.  It trys hard to not re-require
# files.

unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      desired_path = File.expand_path('../' + path.to_str, caller[0])
      shortest = desired_path
      $:.each do |path|
        path += '/'
        if desired_path.index(path) == 0
          candidate = desired_path.sub(path, '')
          shortest = candidate if candidate.size < shortest.size
        end
      end
      require shortest
    end
  end
end
