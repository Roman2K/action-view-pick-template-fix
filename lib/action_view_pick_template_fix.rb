ActionView::Base.class_eval do
  unless private_method_defined? '_unmemoized__pick_template'
    raise "patch not applicable to the current version of ActionView"
  end

  def _unmemoized__pick_template(template_path)
    return template_path if template_path.kind_of? ActionView::Template
    
    # Look in last template's directory first
    directories = _render_stack.map { |template| template.base_path if template.respond_to? :base_path }.compact.uniq
    directories.reverse_each do |directory|
      nesting = template_path.split('/')
      filename = nesting.pop
      begin
        path = [directory].concat(nesting).push(filename).join('/')
        template = _search_for_template_by_path(path) and return template
      end while nesting.shift
    end
    
    # Search using the exact provided path
    template = _search_for_template_by_path(template_path) and return template
    
    # Fallback to uncached lookup
    _build_uncached_template(template_path)
  end
  
private

  def _render_stack
    @_render_stack ||= []
  end
  
  if private_method_defined? '_first_render'
    ActionView::Renderable.class_eval do
      def render_with_stack_update(view, *args, &block)
        view.send(:_render_stack).push(self)
        begin
          render_without_stack_update(view, *args, &block)
        ensure
          view.send(:_render_stack).pop
        end
      end
      alias_method_chain :render, 'stack_update'
    end
  end

  def _search_for_template_by_path(path)
    template = view_paths[path] and return template
    
    path_without_format = File.join(File.dirname(path), File.basename(path).split('.').first)
    formats = _render_stack.map { |template| template.format if template.respond_to? :format }
    formats.insert(1, template_format)
    formats << 'html' if template_format.to_s == 'js'
    formats = formats.compact.map { |format| format.to_s }.uniq
    
    formats.each do |format|
      template = view_paths["#{path_without_format}.#{format}"] and return template
    end
    
    nil
  end
  
  def _build_uncached_template(template_path)
    returning ActionView::Template.new(template_path, view_paths) do
      if self.class.warn_cache_misses && logger
        logger.debug "[PERFORMANCE] Rendering a template that was " +
          "not found in view path. Templates outside the view path are " +
          "not cached and result in expensive disk operations. Move this " +
          "file into #{view_paths.join(':')} or add the folder to your " +
          "view path list"
      end
    end
  end
end
