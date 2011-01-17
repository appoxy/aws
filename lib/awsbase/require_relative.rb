unless respond_to?(:require_relative)
  class Object
    # require_relative was introduced in 1.9.2. This makes it
    # available to younger rubies.
    # From: http://stackoverflow.com/questions/4333286/ruby-require-vs-require-relative-best-practice-to-workaround-running-in-both-r/4338241#4338241
    def require_relative(relative_feature)
      c = caller.first
      fail "Can't parse #{c}" unless c.rindex(/:\d+(:in `.*')?$/)
      file = $`
      if /\A\((.*)\)/ =~ file # eval, etc.
        raise LoadError, "require_relative is called in #{$1}"
      end
      absolute = File.expand_path(relative_feature, File.dirname(file))
      require absolute
    end
  end
end
