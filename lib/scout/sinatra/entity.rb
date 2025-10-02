require 'sinatra/base'
require_relative 'base'            # SinatraScoutHelpers: requested_format, consume_parameter
require_relative 'knowledge_base'            # SinatraScoutHelpers: requested_format, consume_parameter

module SinatraScoutEntity
  def self.registered(app)
    app.register SinatraScoutKnowledgeBase

    # utilities local to the component
    app.helpers do
      def clean_element(elem)
        elem.to_s.gsub('&', '--AND--').
          gsub('/', '-..-').
          gsub("|", '-...-').
          gsub('%', 'o-o').
          gsub('[','(.-(').
          gsub(']',').-)')
      end

      def restore_element(elem)
        CGI.unescape(CGI.unescape(
          elem.gsub('--AND--', '&').
          gsub('-..-', '/').
          gsub('-...-', '|').
          gsub('o-o', '%').
          gsub('(.-(','[').
          gsub(').-)',']')
        ))
      end

      def setup_entity(type, entity, params)
        return Entity.prepare_entity entity, type, params

        base_type, format = type.split ":"
        entity_class = case
                       when Entity.formats.include?(base_type)
                         Entity.formats[base_type] 
                       when Entity.formats.include?(format)
                         Entity.formats[format] 
                       else
                         nil
                       end

        raise "Unknown entity type: #{ type }" if entity_class.nil?

        entity_class.setup(entity, params)
        entity_class.annotations.each{|annotation| params.delete annotation }

        entity.format = format if format and entity.respond_to? :format

        entity
      end

      def entity_template(entity, type = :entity, other = nil)
        file = case type
               when :entity
                 File.join('entity', entity.base_type.to_s)
               when :action, :property
                 File.join('entity', entity.base_type.to_s, other.to_s)
               end 
        return file if ScoutRender.exists?(file)

        file = case type
               when :entity
                 File.join('entity', "Default")
               when :action, :property
                 File.join('entity', "Default", other.to_s)
               end 
        return file if ScoutRender.exists?(file)

        raise TemplateNotFoundException, "Template not found for entity type #{entity.base_type} action #{other}" if other
        raise TemplateNotFoundException, "Template not found for entity type #{entity.base_type}"
      end

      def entity_list_template(list, type = :entity, other = nil)
        file = case type
               when :entity
                 File.join('entity_list', list.base_type.to_s)
               when :action
                 File.join('entity_list', list.base_type.to_s, other.to_s)
               end 
        return file if ScoutRender.exists?(file)

        file = case type
               when :entity
                 File.join('entity_list', 'Default')
               when :action
                 File.join('entity_list', 'Default', other.to_s)
               end 
        return file if ScoutRender.exists?(file)

        raise "Template not found for entity list type #{list.base_type} action #{other}" if other
        raise "Template not found for entity list type #{list.base_type}"
      end

      def render_entity_template(entity, type = :entity, other = nil, params = {})
        template = entity_template(entity, type, other)
        render_template(template, params.merge(entity: entity))
      end

      def entity_list_template(list, type = :entity, other = nil, params = {})
        template = entity_list_template(list, type, other)
        render_template(template, params.merge(list: list))
      end

      def render_entity_partial(entity, type = :entity, other = nil, params = {})
        template = entity_template(entity, type, other)
        render_partial(template, params.merge(entity: entity))
      end

      def entity_list_partial(list, type = :entity, other = nil, params = {})
        template = entity_list_template(list, type, other)
        render_partial(template, params.merge(list: list))
      end

      def entity_url(entity, type = :entity, other = nil, params = {})
        url = '/' + case type
        when :entity
          File.join('entity', entity.base_type.to_s, clean_element(entity))
        when :action
          File.join('entity_action', entity.base_type.to_s, clean_element(other), clean_element(entity))
        when :property
          File.join('entity_property', entity.base_type.to_s, clean_element(other), clean_element(entity))
        end 
        url = add_GET_params(url, params)
        url
      end

      def entity_list_url(list, type = :list, other = nil, params = {})
        url = '/' + case type
        when :list
          File.join('entity_list', list.base_type.to_s, clean_element(list))
        when :action
          File.join('entity_list_action', list.base_type.to_s, clean_element(other), clean_element(list))
        when :property
          File.join('entity_list_property', list.base_type.to_s, clean_element(other), clean_element(list))
        end
        url = add_GET_params(url, params)
        url
      end

      def entity_link(entity, type = :entity, other = nil, params = {})
        link_options = IndiferentHash.pull_keys params, :link
        url = entity_url(entity, type, other)
        link_options = IndiferentHash.add_defaults link_options, class: "entity_#{type}", href: url
        text = IndiferentHash.process_options link_options, :text,
          text: entity.respond_to?(:name) ? entity.name : entity

        html_tag('a', text, link_options)
      end

      def entity_list_link(list, type = :entity, other = nil, params = {})
        link_options = IndiferentHash.pull_keys params, :link
        url = entity_list_url(entity, type, other)
        link_options = IndiferentHash.add_defaults link_options, class: "entity_list_#{type}", href: url
        text = IndiferentHash.process_options link_options, :text,
          text: list

        html_tag('a', text, link_options)
      end

      def entity
        return nil unless entity_type
        return nil unless splat
        @entity ||= begin
                      entity_id = restore_element(splat*"/")

                      if entity_type
                        setup_entity(entity_type, entity_id, params)
                      else
                        entity_id
                      end
                    end
      end

      def entity_render(entity, type = :entity, other = nil, params = {})
        template = entity_template(entity, type, other)

        params = params.merge(entity: entity)
        params = params.merge(check: entity.check) if entity.respond_to?(:check)
        render_template(template, params)
      end

      def entity_list_render(list, list_id, type = :entity, other = nil, params = {})
        template = entity_template(list, type, other)
        render_template(template, params.merge(list: list, list_id: list_id))
      end
    end

    #{{{ SINGLE ENTITIES

    # Entity report
    app.post_get '/entity/:entity_type/*' do
      if _format == :json
        json_halt(200, { id: entity.to_s, info: entity.annotation_hash })
      else
        entity_render(entity, :entity, nil, params)
      end
    end

    app.post_get '/entity_action/:entity_type/:entity_action/*' do
      if _format == :json
        json_halt(501, message: "Action JSON not implemented yet")
      else
        entity_render(entity, :action, entity_action, params)
      end
    end

    app.post_get '/entity_property/:entity_type/:entity_property/*' do
      entity
      entity_property
      args = consume_parameter(:args)

      if args
        prop_params = JSON.parse(args) rescue [args]
      else
        param_names = consume_parameter(:params)
        if param_names
          prop_params = param_names{|param| consume_parameter(param) }
        else
          prop_params = params.values
        end
      end

      value = entity.send(entity_property, *prop_params)

      if Step === value
        job = value
        initiate_step job, _layout

        case _format
        when :job
          redirect to(job_url(job))
        when :json
          serve_step_json job
        else
          serve_step job, _layout do
            entity_render(entity, :property, entity_property, params)
          end
        end
      end

      if _format == :json
        json_halt(200, value)
      else
        begin
          entity_render(entity, :property, entity_property, params)
        rescue TemplateNotFoundException
          json_halt(200, value)
        end
      end
    end

    app.register_common_parameter(:entity_type, :escaped)
    app.register_common_parameter(:entity_action, :escaped)
    app.register_common_parameter(:entity_property, :escaped)
    app.register_common_parameter(:_format, :symbol) do entity_property ? :json : :html end
  end
end
