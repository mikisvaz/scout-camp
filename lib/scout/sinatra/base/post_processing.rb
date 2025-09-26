module SinatraScoutPostProcessing
  class << self
    attr_accessor :post_processing_blocks

    def register_post_processing(&block)
      @post_processing_blocks ||= []
      @post_processing_blocks << block
    end
  end
end
