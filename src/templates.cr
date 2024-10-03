require "crinja"

class Templates
  def initialize
    @env = Crinja.new
    @env.loader = Crinja::Loader::FileSystemLoader.new "templates/"
  end

  def render (template)
    @env.get_template(template).render
  end

  def render (template, ctx)
    @env.get_template(template).render ctx
  end
end
