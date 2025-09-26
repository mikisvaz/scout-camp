require_relative 'post_processing'
module SinatraScoutHelpers
  def self.registered(app)

    app.helpers do
      def json_halt(status, object = nil)
        status, object = 200, status if object.nil? 
        content_type 'application/json'
        halt status, (object.is_a?(String) ? {message: object}.to_json : object.to_json)
      end

      def html_halt(status, text = nil)
        status, text = 200, status if text.nil? 
        content_type 'text/html'
        halt status, text
      end

      def return_json(object)
        json_halt 200, object
      end

      def post_processing(step)
        return unless SinatraScoutPostProcessing.post_processing_blocks
        SinatraScoutPostProcessing.post_processing_blocks.each do |block|
          self.instance_exec step, &block
        end
      end


      def format_name(name)
        parts = name.split("_")
        hash = parts.pop
        clean_name = parts * "_"
        "<span class='name' jobname='#{ name }'>#{ clean_name }</span> <span class='hash'>#{ hash }</span>"
      end
    end
  end
end
