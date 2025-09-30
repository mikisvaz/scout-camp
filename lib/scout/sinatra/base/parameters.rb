module SinatraScoutParameters
  def self.registered(app)
    app.set :common_parameters, []

    app.define_singleton_method(:register_common_parameter) do |name,type=:string,default=nil,&block|
      settings.common_parameters << name
      app.helpers do
        attr_accessor name

        define_method(name) do
          value = self.instance_variable_get(:"@#{name}")
          return value unless value.nil?
          value = consume_parameter(name)
          if value.nil?
            value = if default
                      default
                    elsif block
                      self.instance_eval &block
                    else
                      nil
                    end
          end

          value = case type
                  when :string
                    value.to_s if value
                  when :symbol
                    if String === value
                      value.to_sym
                    else
                      value
                    end
                  when :integer
                    value.to_i
                  when :float
                    value.to_f 
                  when :boolean
                    value.to_s.downcase == "true" unless value.nil?
                  end

          self.instance_variable_set(:"@#{name}", value)
        end
      end
    end

    app.helpers do

      def consume_parameter(name, source = params)
        return nil if source.nil?
        val = IndiferentHash.process_options source, name
        val = nil if val == ''
        val
      end

      def clean_params
        @clean_params ||= begin
                            params = IndiferentHash.setup(self.params)
                            params.keys.each do |param|
                              if param =~ /(.*)_checkbox_false$/
                                params[$1] = false if params[$1].nil?
                                params.delete param
                              elsif param.to_s.start_with? '_'
                                params.delete param
                              end
                            end
                            params
                          end
      end

      def process_common_parameters
        settings.common_parameters.each{|name,*_| self.send(name) }
      end
    end

    app.register_common_parameter(:_layout, :boolean) do ! ajax?  end
    app.register_common_parameter(:_format, :symbol) do :html end
    app.register_common_parameter(:_update, :symbol) do 
      if development? && ! _step
        :development  
      end
    end
    app.register_common_parameter(:_cache_type, :symbol, :asynchronous)
    app.register_common_parameter(:_debug_js, :boolean)
    app.register_common_parameter(:_debug_css, :boolean)
    app.register_common_parameter(:_step, :string)
    app.register_common_parameter(:_)
  end
end
