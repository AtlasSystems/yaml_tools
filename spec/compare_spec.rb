require 'yaml_tools'

RSpec.describe YAMLTools::Comparer do
  originalFilePath = File.join(__dir__, 'support/compare_original.yml');
  modifiedFilePath = File.join(__dir__, 'support/compare_modified.yml');

  describe '#compare' do
    it 'compares' do
      expected = File.read(File.join(__dir__, 'support/compare_expected.yml'));

      comparer = YAMLTools::Comparer.new
      result = comparer.compare_files(originalFilePath, modifiedFilePath, false)

      expect(result).to eq(expected)
    end

    it 'compares including anchors' do
      expected = File.read(File.join(__dir__, 'support/compare_include_anchors_expected.yml'));

      comparer = YAMLTools::Comparer.new
      result = comparer.compare_files(originalFilePath, modifiedFilePath, true)

      expect(result).to eq(expected)
    end

    it 'compares same file' do
      expected = "";

      comparer = YAMLTools::Comparer.new
      result = comparer.compare_files(originalFilePath, originalFilePath, false)

      expect(result).to eq(expected)
    end
  end
end
