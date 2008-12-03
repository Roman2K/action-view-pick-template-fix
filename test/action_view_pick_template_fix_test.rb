require 'test/unit'

require 'action_view'
require 'action_view_pick_template_fix'

require 'action_controller'
require 'action_controller/test_process'

class TestController < ActionController::Base
  prepend_view_path File.dirname(__FILE__) + '/templates'
  def rescue_action(e); raise e end
  
  layout :determine_layout
  
  def code
    respond_to :html, :js
  end
  
  def nested
    respond_to :js
  end
  
  def html_action_in_js
    @html = render_to_string :action => 'only_html'
    respond_to do |format|
      format.js { render :layout => false }
    end
  end
  
  def html_action_in_rjs
    html = render_to_string :action => 'only_html'
    render :update do |page|
      page << ":update : #{html}"
    end
  end
  
  def render_relative_partial
    respond_to :html
  end
  
  def render_same_name_as_previous_relative
    respond_to :html
  end
  
  def render_inline_with_layout
    respond_to do |format|
      format.js { render :inline => "inline", :layout => true }
    end
  end
  
  def render_inline_without_layout
    render :inline => "inline", :layout => false
  end
  
private

  def determine_layout
    case action_name
    when 'render_inline_with_layout'
      'layout_with_partials'
    else
      'layout'
    end
  end
end
ActionController::Routing::Routes.add_route '/test/:action', :controller => 'test'
ActionView::Base.warn_cache_misses = true

class ActionViewPickTemplateFixTest < ActionController::TestCase
  tests TestController
  
  def test_layout_format_is_identical_to_that_of_response
    # HTML response => HTML layout
    accept_html
    get :code
    assert_equal "layout.html.erb : code.html.erb", @response.body
    
    # JS response => JS layout
    accept_js
    get :code
    assert_equal "layout.js.rjs : code.js.erb", @response.body
    
    # Format of partials doesn't matter
    accept_js
    get :nested
    assert_equal "layout.js.rjs : nested.js.erb : _sub.html.erb", @response.body
    
    # HTML in JS
    accept_js
    get :html_action_in_js
    assert_equal "html_action_in_js.js.erb : layout.html.erb : only_html.html.erb", @response.body
    
    # HTML in RJS
    accept_js
    get :html_action_in_rjs
    assert_equal ":update : layout.html.erb : only_html.html.erb", @response.body
  end
  
  def test_partials_are_looked_for_in_parent_template_dir_first
    accept_html
    get :render_relative_partial
    expected =  "layout.html.erb : " \
                "render_relative_partial.html.erb : " \
                "alternative/has_partials.html.erb : " \
                "alternative/_foo.html.erb + alternative/bar/_baz.html.erb"
    assert_equal expected, @response.body
    
    # verify that _foo has not been cached to the template found the first time around
    accept_html
    get :render_same_name_as_previous_relative
    assert_equal "layout.html.erb : render_same_name_as_previous_relative.html.erb : _foo.html.erb", @response.body
    
    # doesn't break inline templates
    accept_html
    get :render_inline_without_layout
    assert_equal "inline", @response.body
  end
  
  def test_layout_format_is_not_hindered_by_inline_templates
    # Accept JS / inline template for action / JS layout rendering some HTML in it
    # => other partials should be rendered in JS
    accept_js
    get :render_inline_with_layout
    assert_equal "layout_with_partials.js.erb : code.html.erb : inline : code.js.erb", @response.body
  end
  
private

  def accept_html
    @request.accept = 'text/html'
  end
  
  def accept_js
    @request.accept = 'application/x-javascript'
  end
end
