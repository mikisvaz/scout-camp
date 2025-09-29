module ScoutRenderHelpers
  def escape_html(text)
    Rack::Utils.escape_html(text)
  end

  def hash_to_html_tag_attributes(hash)
    return "" if hash.nil? or hash.empty?
    hash.collect{|k,v| 
      case 
      when (k.nil? or v.nil? or (String === v and v.empty?))
        nil
      when Array === v
        [k,"'" << v * " " << "'"] * "="
      when String === v
        [k,"'" << v << "'"] * "="
      when Symbol === v
        [k,"'" << v.to_s << "'"] * "="
      when TrueClass === v
        [k,"'" << v.to_s << "'"] * "="
      when Numeric === v
        [k,"'" << v.to_s << "'"] * "="
      else
        nil
      end
    }.compact * " "
  end

  def html_tag(tag, content = nil, params = {})
    attr_str = hash_to_html_tag_attributes(params)
    attr_str = " " << attr_str if String === attr_str and attr_str != ""
    html = if content.nil?
      "<#{ tag }#{attr_str}/>"
    else
      "<#{ tag }#{attr_str}>#{ content.to_s }</#{ tag }>"
    end

    html
  end

  def remove_GET_param(url, param)
    if Array === param
      param.each do |p|
        url = remove_GET_param(url, p)
      end
    else
      url = url.gsub(/(\?|&)#{param}=[^&]+/,'\1')
    end

    url = url.sub(/&&*/, '&')
    url = url.sub(/&$/, '')
    url = url.sub(/\?$/,'')
    url
  end

  def add_GET_param(url, param, value)
    url = remove_GET_param(url, param)
    if url =~ /\?.+=/
      url + "&#{ param }=#{ value }"
    else
      url + "?#{ param }=#{ value }"
    end
  end

  def add_GET_params(url, params)
    params.each do |k,v|
      url = add_GET_param(url, k, v)
    end
    url
  end

  def add_checks(checks)
    return unless Step === @step
    current_checks = @step.info[:checks] || []
    current_checks += Array === checks ? checks : [checks]
    @step.set_info :checks, current_checks.uniq
  end

  def outdated?
    return false unless Step === @step
    return false unless @step.path.exists?
    current_checks = @step.info[:checks] || []
    @step.path.outdated?(current_checks)
  end
end
