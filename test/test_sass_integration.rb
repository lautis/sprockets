require 'sprockets_test'

class TestSassIntegration < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.paths << fixture_path('sass')
    @env.register_engine :scss, Sprockets::ScssTemplate
  end

  test "sass imports" do
    assert_equal <<CSS, @env["application.css.scss"].to_s
.partial-sass {
  color: green; }

.top-level {
  font-color: bold; }

.sub-folder-relative-scss {
  width: 250px; }

.partial-scss {
  color: blue; }

.sub-folder-relative-sass {
  width: 50px; }

.not-a-partial {
  border: 1px solid blue; }

.main {
  color: yellow;
  background-color: red; }
CSS
  end
end
