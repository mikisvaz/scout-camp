require 'scout/knowledge_base'

module SinatraScoutKnowledgeBase
  def self.registered(app)
    # helpers for REST-style responses & params
    app.set :knowledge_base, KnowledgeBase.load(:default)
    
    app.helpers do
      def knowledge_base
        settings.knowledge_base
      end
    end
  end
end
