require 'yaml_tools'

RSpec.describe YAMLTools::Comparer do
  sourceFilePath = File.join(__dir__, 'support/compare_source.yml');
  differenceFilePath = File.join(__dir__, 'support/compare_difference.yml');

  describe '#compare' do
    it 'compares' do
      expected = File.read(File.join(__dir__, 'support/compare_expected.yml'));

      comparer = YAMLTools::Comparer.new
      result = comparer.compare_files(sourceFilePath, differenceFilePath, false)

      expect(result).to eq(expected)
    end

    it 'compares including anchors' do
        expected = File.read(File.join(__dir__, 'support/compare_include_anchors_expected.yml'));

        comparer = YAMLTools::Comparer.new
        result = comparer.compare_files(sourceFilePath, differenceFilePath, true)

        expect(result).to eq(expected)
      end
  end
end
