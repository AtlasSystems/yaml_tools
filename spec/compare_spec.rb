require 'yaml_tools'

RSpec.describe YAMLTools::Comparer do
  describe '#compare' do
    it 'compare two IO' do
      source = StringIO.new("root:\n  test: Test\n");
      difference = StringIO.new("root:\n  test: Test\n  new: New\n");

      comparer = YAMLTools::Comparer.new
      result = comparer.compare(source, difference)

      expect(result).to eq("root:\n  new: New\n")
    end
  end
end
