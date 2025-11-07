module SinatraScoutFinder
  def self.registered(app)
    app.helpers do
      def finder
        nil
      end
    end
  end
end
