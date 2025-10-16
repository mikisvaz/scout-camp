
module SinatraScoutHTMX
  
  def self.registered(app)
    app.before do
      headers "X-Frame-Options" => "DENY"
    end

    app.after do
      triggers = []

      status = case response.status
               when 200
                 ['done', 'complete']
               when 500
                 ['error', 'complete']
               when 202
                 ['running']
               else
                 []
               end

      if defined?(entity_type) && entity_type
        entity = (splat*"/").gsub(/\s/,'_')
        triggers << 'entity' 
        triggers << entity_type
        triggers << entity 
        triggers << [entity_type, entity]*'_'
      end

      if defined?(entity_property) && entity_property
        triggers << 'entity_property' 
        triggers << [entity_type, entity_property]*'_'
        triggers << [entity, entity_property]*'_'
        triggers << [entity_type, entity, entity_property]*'_'
        triggers << entity_property
      end

      if defined?(entity_action) && entity_action
        triggers << 'entity_action' 
        triggers << [entity_type, entity_action]*'_'
        triggers << [entity, entity_action]*'_'
        triggers << [entity_type, entity, entity_action]*'_'
        triggers << entity_action
      end

      if defined?(task_name) && task_name
        triggers << 'task' 
        triggers << task_name
        triggers << [workflow, task_name]*"_"
      end

      if defined?(preferences_changed) && preferences_changed.any?
        triggers << ['preference'] 
        preferences_changed.each do |preference|
          triggers << [preference] 
          triggers << ['preference_' + preference] 
        end
      end

      triggers += triggers.collect{|t| status.collect{|s| [t, s]*"_" }}.flatten

      triggers << status

      headers['HX-Trigger'] = triggers * ", "
    end
  end
end
