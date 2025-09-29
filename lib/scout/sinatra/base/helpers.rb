require_relative 'post_processing'
module SinatraScoutHelpers
  def self.registered(app)

    app.helpers do
      def format_name(name)
        parts = name.split("_")
        hash = parts.pop
        clean_name = parts * "_"
        "<span class='name' jobname='#{ name }'>#{ clean_name }</span> <span class='hash'>#{ hash }</span>"
      end
    end
  end
end
