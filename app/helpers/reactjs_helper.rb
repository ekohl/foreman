require 'json'

module ReactjsHelper
  # Mount react component in views
  # Params:
  # +name+:: the component name from the componentRegistry
  # +props+:: props to pass to the component
  #          valid value types: Hash, json-string, nil
  def react_component(name, props = {})
    props = props.to_json if props.is_a?(Hash)

    content_tag('foreman-react-component', '', :name => name, :data => { props: props })
  end

  def webpacked_plugins_js_for(*plugin_names)
    js_tags_for(select_requested_plugins(plugin_names)).join.html_safe
  end

  def webpacked_plugins_with_global_js
    global_js_tags(Foreman::Plugin.with_global_js).join.html_safe
  end

  def webpacked_plugins_css_for(*plugin_names)
    Foreman::Deprecation.deprecation_warning('3.12', '`webpacked_plugins_css_for` is deprecated, plugin css is already loaded.')
    nil
  end

  def read_webpack_manifest
    JSON.parse(Rails.root.join('public/webpack/manifest.json').read)
  end

  def get_webpack_foreman_vendor_js
    Rails.cache.fetch('webpack_foreman_vendor_js', expires_in: 1.minute) do
      data = read_webpack_manifest
      foreman_vendor_js = data['assetsByChunkName']['foreman-vendor'].find { |value| value.end_with?('.js') }
      javascript_include_tag("/webpack/#{foreman_vendor_js}")
    end
  end

  def get_webpack_foreman_vendor_css
    data = read_webpack_manifest
    foreman_vendor_css = data['assetsByChunkName']['foreman-vendor'].find { |value| value.end_with?('.css') }
    stylesheet_link_tag("/webpack/#{foreman_vendor_css}")
  end

  def select_requested_plugins(plugin_names)
    available_plugins = Foreman::Plugin.with_webpack.map(&:id)
    missing_plugins = plugin_names - available_plugins
    if missing_plugins.any?
      logger.error { "Failed to include webpack assets for plugins: #{missing_plugins}" }
      raise ::Foreman::Exception.new("Failed to include webpack assets for plugins: #{missing_plugins}") if Rails.env.development?
    end
    plugin_names & available_plugins
  end

  def js_tags_for(requested_plugins)
    requested_plugins.map do |plugin|
      name = plugin.to_s.tr('-', '_')
      javascript_tag("window.tfm.tools.loadPluginModule('/webpack/#{name}','#{name}','./index');".html_safe)
    end
  end

  def global_js_tags(requested_plugins)
    requested_plugins.map do |plugin|
      # Was this ever intended as a plugin api?
      if plugin.is_a?(Hash)
        Foreman::Deprecation.deprecation_warning('3.12', '`global_js_tags` with hashes is deprecated. Pass in Foreman::Plugin instances')
        plugin = Foreman::Plugin.find(plugin['id'])
      end

      plugin.global_js_files.map do |file|
        name = plugin.id.to_s.tr('-', '_')
        javascript_tag("window.tfm.tools.loadPluginModule('/webpack/#{name}','#{name}','./#{file}_index');".html_safe)
      end
    end
  end

  def css_tags_for(requested_plugins)
    Foreman::Deprecation.deprecation_warning('3.12', '`css_tags_for` is deprecated, No need to load CSS separately, since it should be referenced from the corresponding JS file.')
    []
  end

  def locale_js_tags
    locale = FastGettext.locale
    ::Foreman::Plugin.all.filter_map do |plugin|
      domain = plugin.gettext_domain
      if domain && (FastGettext.translation_repositories[domain]&.available_locales || []).include?(locale)
        javascript_include_tag("#{plugin.name}/locale/#{locale}/#{domain}")
      end
    end.join.html_safe
  end
end
