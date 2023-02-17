require 'yaml_tools'

RSpec.describe YAMLTools::Combiner do
  describe '#combine' do
    it 'combines two IO' do
      source = StringIO.new("root:\n  test: Test\n");
      difference = StringIO.new("root:\n  new: New\n");

      combiner = YAMLTools::Combiner.new
      result = combiner.combine(source, difference)

      expect(result).to eq("root:\n  test: Test\n  new: New\n")
    end
  end
end
