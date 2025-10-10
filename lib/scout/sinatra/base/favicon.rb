module SinatraScoutFavicon
  def self.registered(app)
    app.get '/favicon.ico' do
      content_type 'image/svg+xml'
      cache_control :public, max_age: 86_400 # 1 day

      <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" role="img" aria-label="Compass favicon">
        <!-- outer circle -->
        <circle cx="32" cy="32" r="28" fill="none" stroke="currentColor" stroke-width="2" />
        <!-- ticks for N/E/S/W -->
        <line x1="32" y1="4"  x2="32" y2="10" fill="none" stroke="currentColor" stroke-width="2" />
        <line x1="60" y1="32" x2="54" y2="32" fill="none" stroke="currentColor" stroke-width="2" />
        <line x1="32" y1="60" x2="32" y2="54" fill="none" stroke="currentColor" stroke-width="2" />
        <line x1="4"  y1="32" x2="10" y2="32" fill="none" stroke="currentColor" stroke-width="2" />
        <!-- inner degree markers -->
        <g stroke="currentColor" stroke-width="1">
          <line x1="32" y1="12" x2="32" y2="14"/>
          <line x1="45" y1="19" x2="43" y2="21"/>
          <line x1="52" y1="32" x2="50" y2="32"/>
          <line x1="45" y1="45" x2="43" y2="43"/>
          <line x1="32" y1="52" x2="32" y2="50"/>
          <line x1="19" y1="45" x2="21" y2="43"/>
          <line x1="12" y1="32" x2="14" y2="32"/>
          <line x1="19" y1="19" x2="21" y2="21"/>
        </g>
        <!-- compass needle (line drawing) -->
        <g stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round" fill="none">
          <!-- main spine -->
          <line x1="32" y1="32" x2="42" y2="12"/>
          <line x1="32" y1="32" x2="22" y2="52"/>
          <!-- needle outlines (simple triangular tips) -->
          <path d="M42 12 L36 20 L32 18 Z" fill="none" stroke="currentColor" stroke-width="1.6"/>
          <path d="M22 52 L28 44 L32 46 Z" fill="none" stroke="currentColor" stroke-width="1.6"/>
        </g>
        <!-- center hub -->
        <circle cx="32" cy="32" r="2" fill="currentColor" />
      </svg>
      SVG
    end
  end
end
