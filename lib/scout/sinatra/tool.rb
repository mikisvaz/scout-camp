module ScoutRenderHelpers
  def tool(name, params = {})
    render_template("tool/#{name}", params)
  end
end
