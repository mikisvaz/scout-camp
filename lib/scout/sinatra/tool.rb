module SinatraScoutTool
  def self.registered(app)
    app.helpers do
      def tool(name, params = {})
        record_js "/js/tool/#{name}.js" if ScoutRender.exists?("public/js/tool/#{name}.js")
        record_css "/css/tool/#{name}.css" if ScoutRender.exists?("public/css/#{name}.css")
        render_partial("tool/#{name}", params)
      end
    end
  end
end
