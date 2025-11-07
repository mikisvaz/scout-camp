module SinatraScoutPostProcessing
  def self.registered(app)
    app.set :post_processing_blocks, []

    app.define_singleton_method(:register_post_processing) do |&block|
      settings.post_processing_blocks << block
    end

    app.helpers do
      def post_processing(step)
        return unless settings.post_processing_blocks
        settings.post_processing_blocks.each do |block|
          self.instance_exec step, &block
        end
      end
    end
  end
end
