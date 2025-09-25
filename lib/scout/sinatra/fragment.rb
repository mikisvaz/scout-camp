require_relative 'render/parameters'

module ScoutRenderHelpers
  def fragment(link = nil, &block)
    fragment_code, link = [link.to_s, nil] if link and not link.to_s[0] == '<'
    text = fragment_code if fragment_code

    if block_given?
      if defined? @step and (_cache_type == :asynchronous or _cache_type == :async)

        fragment_code ||= (rand * 100000).to_i.to_s
        fragment_file = @step.file(fragment_code)
        pid_file = fragment_file + '.pid'

        pid = @step.child{
          begin
            class << @step
              def status=(message)
                nil
              end
            end
            Log.low("Fragment started: #{ fragment_file } - #{Process.pid}")
            res = block.call fragment_file
            Log.low("Fragment writing: #{ fragment_file } - #{Process.pid}")
            Open.write(fragment_file, res) unless res.nil?
            Log.low("Fragment done: #{ fragment_file } - #{Process.pid}")
          rescue Exception
            Open.write(fragment_file + '.error', [$!.class.to_s, $!.message] * ": ")
            Open.write(fragment_file + '.backtrace', $!.backtrace * "\n") if $!.backtrace
            Log.error("Error in fragment: #{ fragment_file }")
            Log.exception $!
            Open.rm pid_file if Open.exists? pid_file
            Kernel.exit! -1
          ensure
            Open.rm pid_file if Open.exists? pid_file
          end
          Kernel.exit! 0
        }
        Open.write(pid_file, pid.to_s)

        url = fullpath 
        url = remove_GET_param(url, "_update")
        url = remove_GET_param(url, "_")

        fragment_url = add_GET_param(url, "_fragment", fragment_code)
        if link.nil?
          html_tag('a', "", :href => fragment_url, :class => 'fragment', "data-text" => text)
        else
          if FalseClass === link
            return fragment_code
          elsif TrueClass === link
            return fragment_url
          elsif link =~ / href=/
            link = link.sub(/ href=('|")/," href='#{fragment_url}'")
          else
            link = link.sub(/<a /,"<a href='#{fragment_url}' ")
          end

          if text
            link.sub(/<a /,"<a data-text='#{text}' ")
          else
            link
          end
        end
      else
        block.call
      end
    else
      if link =~ / class=/
        link = link.sub(/ class=('|")/,' class=\1fragment ')
      else
        link = link.sub(/<a /,'<a class="fragment" ')
      end
      
      if text
        link.sub(/<a /,"<a data-text='#{text}' ")
      else
        link
      end
    end
  end
end

module SinatraScoutFragment
  def self.registered(app)
    app.helpers do
      # keep a small param consumer (safe)
      def process_fragment(fragment_code)
        fragment_file = @step.file(fragment_code)
        if Open.exists?(fragment_file)
          case _format.to_s
          when "query-entity"
            tsv, table_options = load_tsv(fragment_file, true)
            begin
              res = tsv[@entity].to_json
              content_type "application/json" 
            rescue
              res = nil.to_json
            end
            halt 200, res 
          when "query-entity-field"
            tsv, table_options = load_tsv(fragment_file, true)
            begin
              res = tsv[@entity]
              res = [res] if tsv.type == :single or tsv.type == :flat
            rescue
              res = nil.to_json
            end

            fields = tsv.fields
            content_type "application/json" 
            hash = {}
            fields.each_with_index do |f,i|
              hash[f] = res.nil? ? nil : res[i]
            end

            halt 200, hash.to_json 
          when "table"
            html_halt tsv2html(fragment_file)
          when "json"
            content_type "application/json" 
            halt 200, tsv_process(load_tsv(fragment_file).first).to_json
          when "tsv"
            content_type "text/tab-separated-values"
            halt 200, tsv_process(load_tsv(fragment_file).first).to_s
          when "values"
            tsv = tsv_process(load_tsv(fragment_file).first)
            list = tsv.values.flatten
            content_type "application/json" 
            halt 200, list.compact.to_json
          when "entities"
            raw_tsv, tsv_options = load_tsv(fragment_file)
            tsv = tsv_process(raw_tsv)

            list = tsv.values.flatten
            list = tsv.prepare_entity(list, tsv.fields.first, tsv.entity_options)
            type = list.annotation_types.last
            list_id = "List of #{type} in table #{ @fragment }"
            list_id << " (#{ @filter })" if @filter
            Entity::List.save_list(type.to_s, list_id, list, user)
            url =  Entity::REST.entity_list_url(list_id, type)
            url = url + '?_layout=false' unless @layout
            url = escape_url(url)
            redirect to(url)
          when "map"
            raw_tsv, tsv_options = load_tsv(fragment_file)
            raw_tsv.unnamed = true
            tsv = tsv_process(raw_tsv)

            field = tsv.key_field
            column = tsv.fields.first

            if tsv.entity_templates[field] 
              type = tsv.entity_templates[field].annotation_types.first
            else
              type = [Entity.formats[field]].compact.first || field
            end

            map_id = "Map #{type}-#{column} in #{ @fragment }"
            map_id << " (#{ @filter.gsub(';','|') })" if @filter
            Entity::Map.save_map(type.to_s, column, map_id, tsv, user)
            url = Entity::REST.entity_map_url(map_id, type, column)
            url = url + '?_layout=false' unless @layout
            url = escape_url(url)
            redirect to(url)
          when "excel"
            require 'rbbt/tsv/excel'
            tsv, tsv_options = load_tsv(fragment_file)
            tsv = tsv_process(tsv)
            data = nil
            excel_file = TmpFile.tmp_file
            tsv.excel(excel_file, :sort_by => @excel_sort_by, :sort_by_cast => @excel_sort_by_cast, :name => true, :remove_links => true)
            name = tsv_options[:table_id]
            name ||= "rbbt-table"
            name = name.sub(/\s/,'_')
            name = name.sub('.tsv','')
            send_file excel_file, :type => 'application/vnd.ms-excel', :filename => "#{name}.xls"
          when "heatmap"
            require 'rbbt/util/R'
            tsv, tsv_options = load_tsv(fragment_file)
            content_type "text/html"
            data = nil
            png_file = TmpFile.tmp_file + '.png'
            width = tsv.fields.length * 10 + 500
            height = tsv.size * 10 + 500
            width = 10000 if width > 10000
            height = 10000 if height > 10000
            tsv.R <<-EOF
rbbt.pheatmap(file='#{png_file}', data, width=#{width}, height=#{height})
data = NULL
            EOF
            send_file png_file, :type => 'image/png', :filename => fragment_file + ".heatmap.png"
          when 'binary'
            send_file fragment_file, :type => 'application/octet-stream'
          else
            require 'mimemagic'
            mime = nil
            Open.open(fragment_file) do |io|
              begin
                mime = MimeMagic.by_path(fragment_file) 
                if mime.nil?
                  io.rewind
                  mime = MimeMagic.by_magic(io) 
                end
                if mime.nil?
                  io.rewind if IO === io
                  mime = "text/tab-separated-values" if io.gets =~ /^#/ and io.gets.include? "\t"
                end
              rescue Exception
                Log.exception $!
              end
            end

            if mime.nil?
              txt = Open.read(fragment_file)

              if txt =~ /<([^> ]+)[^>]*>.*?<\/\1>/m
                mime = "text/html"
              else
                begin
                  JSON.parse(txt)
                  mime = "application/json"
                rescue
                end
              end
            else
              txt = nil
            end

            if mime
              content_type mime 
            else
              content_type "text/plain"
            end

            if mime && mime.to_s.include?("text/html")
              html_halt txt || Open.read(fragment_file)
            else
              if File.exist?(fragment_file)
                send_file fragment_file
              else
                halt 200, Open.read(fragment_file)
              end
            end
          end
        elsif Open.exists?(fragment_file + '.error') 
          klass, _sep, message = Open.read(fragment_file + '.error').partition(": ")
          backtrace = Open.read(fragment_file + '.backtrace').split("\n")
          exception =  Kernel.const_get(klass).new message || "no message"
          exception.set_backtrace backtrace
          raise exception
          #halt 500, html_tag(:span, File.read(fragment_file + '.error'), :class => "message") + 
          #  html_tag(:ul, File.read(fragment_file + '.backtrace').split("\n").collect{|l| html_tag(:li, l)} * "\n", :class => "backtrace") 
        elsif Open.exists?(fragment_file + '.pid') 
          pid = Open.read(fragment_file + '.pid')
          if Misc.pid_exists?(pid.to_i)
            halt 202, "Fragment not completed"
          else
            halt 500, "Fragment aborted"
          end
        else
          halt 500, "Fragment not completed and no pid file"
        end
      end
    end
  end
end

SinatraScoutParameters.register_common_parameter(:_fragment, :string)

SinatraScoutRender.register_post_processing do |step|
  if _fragment
    process_fragment(_fragment)
  end
end
