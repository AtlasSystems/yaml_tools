require 'yaml_tools'

RSpec.describe YAMLTools::Combiner do
  sourceFilePath = File.join(__dir__, 'support/combine_source.yml');
  differenceFilePath = File.join(__dir__, 'support/combine_difference.yml');

  describe '#combine' do
    it 'combines' do
      expected = File.read(File.join(__dir__, 'support/combine_expected.yml'));

      combiner = YAMLTools::Combiner.new
      result = combiner.combine_files(sourceFilePath, differenceFilePath)

      expect(result).to eq(expected)
    end
  end
end
