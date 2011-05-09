# require_relative was introduced in 1.9.2. This makes it
# available to younger rubies.
# From: http://stackoverflow.com/questions/4333286/ruby-require-vs-require-relative-best-practice-to-workaround-running-in-both-r/4338241#4338241
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
#      puts 'IN NEW REQUIRE_RELATIVE ' + path.to_s
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end
