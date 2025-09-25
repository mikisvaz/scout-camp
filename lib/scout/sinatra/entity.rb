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
        case type
        when :entity
          File.join('entity', entity.base_type.to_s)
        when :action
          File.join('entity', entity.base_type.to_s, other.to_s)
        end 
      end

      def entity_list_template(list, type = :entity, other = nil)
        case type
        when :entity
          File.join('entity_list', list.base_type.to_s)
        when :action
          File.join('entity_list', list.base_type.to_s, other.to_s)
        end 
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
    end

    #{{{ SINGLE ENTITIES

    # Entity report
    app.get '/entity/:entity_type/:entity' do
      entity_type = restore_element(consume_parameter(:entity_type))
      entity_id = restore_element(consume_parameter(:entity))

      # build entity instance with annotations collected from query string (use helpers)
      entity = setup_entity(entity_type, entity_id, params)   # uses EntityRESTHelpers.setup_entity

      params[:entity] = entity

      if _format == :json
        # Simple JSON representation (entity.info + id)
        json_halt(200, { id: entity.to_s, info: entity.annotation_hash })
      else
        # Render Haml template via ScoutRender and return content
        content_type 'text/html'
        begin
          render_template("entity/#{entity.base_type}", params)
        rescue TemplateNotFoundException
          render_template("entity/Default", params)
        end
      end
    end

    # Entity action (page)
    app.get '/entity_action/:entity_type/:action/:entity' do
      entity_type = restore_element(consume_parameter(:entity_type))
      entity_id = restore_element(consume_parameter(:entity))
      action = consume_parameter(:action)

      entity = setup_entity(entity_type, entity_id, params)

      params[:entity] = entity

      if _format == :json
        json_halt(501, message: "Action JSON not implemented yet")
      else
        render_template("entity/#{entity.base_type}/#{action}", params)
      end
    end

    # Entity property (JSON)
    app.get '/entity_property/:entity_type/:property/:entity' do
      property = consume_parameter(:property)
      entity_type = restore_element(consume_parameter(:entity_type))
      entity_id = restore_element(consume_parameter(:entity))

      args = consume_parameter(:args)
      args = args ? (JSON.parse(args) rescue [args]) : []

      entity = setup_entity(entity_type, entity_id, params)
      begin
        value = entity.send(property, *args)
      rescue => e
        json_halt(500, message: "Property call failed: #{e.message}")
      end
      json_halt(200, value)
    end

    #{{{ LISTS OF ENTITIES

    # Entity list endpoints
    app.get '/entity_list/:entity_type/:list_id' do
      entity_type = restore_element(consume_parameter(:entity_type))
      list_id = restore_element(consume_parameter(:list_id))

      list = knowledge_base.load_list(list_id, entity_type.split(":").first)

      params[:list] = list
      params[:list_id] = list_id

      case _format
      when :json
        json_halt(200, {entities: list, info: list.annotation_hash, types: list.annotation_types})
      when :html
        content_type 'text/html'
        begin
          render_template("entity_list/#{entity_type}", params)
        rescue TemplateNotFoundException => e
          render_template("entity_list/Default", params)
        rescue TemplateNotFoundException
          raise e
        end
      else
        content_type 'text/tab-separated-values'
        list.to_s
      end
    end

    # Entity list actions (page)
    app.get '/entity_list_action/:entity_type/:action/:list_id' do
      entity_type = restore_element(consume_parameter(:entity_type))
      action = consume_parameter(:action)
      list_id = restore_element(consume_parameter(:list_id))

      list = knowledge_base.load_list(list_id, entity_type.split(":").first)

      params[:list] = list
      params[:list_id] = list_id

      if _format == :json
        json_halt(501, message: "List action JSON not implemented")
      else
        return_html("entity_list_action/#{entity.base_type}", params)
      end
    end

    # Entity list property (page)
    app.get '/entity_list_property/:entity_type/:property/:list_id' do
      entity_type = restore_element(consume_parameter(:entity_type))
      list_id = restore_element(consume_parameter(:list_id))

      list = knowledge_base.load_list(list_id, entity_type.split(":").first)

      params[:list] = list
      params[:list_id] = list_id

      args = consume_parameter(:args)
      args = args ? (JSON.parse(args) rescue [args]) : []

      begin
        value = list.send(property, *args)
      rescue => e
        json_halt(500, message: "Property call failed: #{e.message}")
      end
      json_halt(200, value)
    end

    # Map rendering
    app.get '/entity_map/:entity_type/:column/:map_id' do
      entity_type = restore_element(consume_parameter(:entity_type))
      column = restore_element(consume_parameter(:column))
      map_id = restore_element(consume_parameter(:map_id))

      map = knowledge_base.load_map(entity_type.split(":").first, column, map_id, nil)

      fmt = _format
      case fmt
      when :json
        respond_with_json(map.to_h) rescue respond_with_json({ error: "Map serialization failed" })
      when :html
        render_html_template("entity_map/#{entity_type.split(':').first}/Default", map: map, map_id: map_id)
      else
        content_type 'text/tab-separated-values'
        map.to_s
      end
    end

    # Favourite endpoints (simple JSON)
    app.post '/add_favourite_entity/:entity_type/:entity' do
      entity_type = restore_element(consume_parameter(:entity_type))
      entity_id = restore_element(consume_parameter(:entity))
      entity = setup_entity(entity_type, entity_id, params)
      add_favourite_entity(entity)
      status 200
      body({ok: true}.to_json)
    end

    app.post '/remove_favourite_entity/:entity_type/:entity' do
      entity_type = restore_element(consume_parameter(:entity_type))
      entity_id = restore_element(consume_parameter(:entity))
      entity = setup_entity(entity_type, entity_id, params)
      remove_favourite_entity(entity)
      status 200
      body({ok: true}.to_json)
    end

    app.get '/favourite_entities' do
      json_halt(401, message: "Login required") unless respond_to?(:user) && user
      respond_with_json(favourite_entities)
    end

    # more endpoints can be added similarly...
  end
end
