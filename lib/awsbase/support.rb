# If ActiveSupport is loaded, then great - use it.  But we don't 
# want a dependency on it, so if it's not present, define the few
# extensions that we want to use...
unless defined? ActiveSupport
    # These are ActiveSupport-;like extensions to do a few handy things in the gems
    # Derived from ActiveSupport, so the AS copyright notice applies:
    #
    #
    #
    # Copyright (c) 2005 David Heinemeier Hansson
    #
    # Permission is hereby granted, free of charge, to any person obtaining
    # a copy of this software and associated documentation files (the
    # "Software"), to deal in the Software without restriction, including
    # without limitation the rights to use, copy, modify, merge, publish,
    # distribute, sublicense, and/or sell copies of the Software, and to
    # permit persons to whom the Software is furnished to do so, subject to
    # the following conditions:
    #
    # The above copyright notice and this permission notice shall be
    # included in all copies or substantial portions of the Software.
    #
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
    # LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    # OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    # WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    #++
    #
    #
    class String #:nodoc:

        # Constantize tries to find a declared constant with the name specified
        # in the string. It raises a NameError when the name is not in CamelCase
        # or is not initialized.
        #
        # Examples
        #   "Module".constantize #=> Module
        #   "Class".constantize #=> Class
        def constantize()
            camel_cased_word = self
            names = camel_cased_word.split('::')
            names.shift if names.empty? || names.first.empty?

            constant = Object
            names.each do |name|
                constant = constant.const_get(name, false) || constant.const_missing(name)
            end
            constant
        end

    		# By default, +camelize+ converts strings to UpperCamelCase. If the argument to +camelize+
    		# is set to <tt>:lower</tt> then +camelize+ produces lowerCamelCase.
    		# 
    		# +camelize+ will also convert '/' to '::' which is useful for converting paths to namespaces.
    		# 
    		# Examples:
    		#   "active_record".camelize                # => "ActiveRecord"
    		#   "active_record".camelize(:lower)        # => "activeRecord"
    		#   "active_record/errors".camelize         # => "ActiveRecord::Errors"
    		#   "active_record/errors".camelize(:lower) # => "activeRecord::Errors"
    		def camelize(lower_case_and_underscored_word=self, first_letter_in_uppercase = true)
      		if first_letter_in_uppercase
        		lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      		else
        		lower_case_and_underscored_word.first.downcase + camelize(lower_case_and_underscored_word)[1..-1]
      		end
    		end

    # The reverse of +camelize+. Makes an underscored, lowercase form from the expression in the string.
    #
    # Changes '::' to '/' to convert namespaces to paths.
    #
    # Examples:
    #   "ActiveRecord".underscore         # => "active_record"
    #   "ActiveRecord::Errors".underscore # => active_record/errors
    def underscore
      self.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
			

    end


    class Object #:nodoc:
        # "", "   ", nil, [], and {} are blank
        def blank?
            if respond_to?(:empty?) && respond_to?(:strip)
                empty? or strip.empty?
            elsif respond_to?(:empty?)
                empty?
            else
                !self
            end
        end
    end

    class NilClass #:nodoc:
        def blank?
            true
        end
    end

    class FalseClass #:nodoc:
        def blank?
            true
        end
    end

    class TrueClass #:nodoc:
        def blank?
            false
        end
    end

    class Array #:nodoc:
        alias_method :blank?, :empty?
    end

    class Hash #:nodoc:
        alias_method :blank?, :empty?

        # Return a new hash with all keys converted to symbols.
        def symbolize_keys
            inject({}) do |options, (key, value)|
                options[key.to_sym] = value
                options
            end
        end
    end

    class String #:nodoc:
        def blank?
            empty? || strip.empty?
        end
    end

    class Numeric #:nodoc:
        def blank?
            false
        end
    end
end
