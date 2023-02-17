require 'yaml'

module YAMLTools
  class Comparer
    @source_anchors = {}
    @modified_anchors = []

    def processLevel (s, d, includeAnchorDependencies)
      level = []

      # Split into key/value pairs
      sourceChildren = s.each_slice(2).to_a
      destinationChildren = d.each_slice(2).to_a

      # Add all anchors for this level for use when performing potential comparisons later
      sourceChildren.find_all {|i| !i[1].is_a?(Psych::Nodes::Alias) && !i[1].anchor.nil?}.each {|i| @source_anchors[i[1].anchor] = i[1]}

      destinationChildren.each {|destinationPair|
        destinationKey = destinationPair[0]
        destinationValue = destinationPair[1]

        # Find source pair
        sourcePairs = sourceChildren.find_all {|i| i[0].value == destinationKey.value}

        if (sourcePairs.length > 1) then
          if (destinationKey.value == "<<") then
            # Find merge key with matching alias
            sourcePair = sourcePairs.find {|i| i[1].is_a?(Psych::Nodes::Alias) && i[1].anchor == destinationValue.anchor}
          else
            # Some ArchivesSpace files have duplicate keys so use the last one
            sourcePair = sourcePairs.last
          end
        else
          sourcePair = sourcePairs.first
        end

        if (sourcePair == nil) then
          # Source not found so copy node
          level << destinationKey
          level << destinationValue
        else
          sourceKey = sourcePair[0]
          sourceValue = sourcePair[1]

          if (sourceKey.value == "<<") then
            # Handle merge keys specifically since they can be an individual alias or a sequence or aliases

            if (sourceValue.is_a?(Psych::Nodes::Sequence)) then
              if (destinationValue.is_a?(Psych::Nodes::Sequence)) then
                if (sourceValue.children.length == destinationValue.children.length) then
                  # Compare sequences
                  sourceValue.children.each_with_index {|a, index|
                    if (a.anchor != destinationValue.children[index].anchor || (includeAnchorDependencies && @modified_anchors.include?(destinationValue.children[index].anchor))) then
                      # Different aliases or ordering
                      level << destinationKey
                      level << destinationValue
                      break
                    end
                  }
                else
                  # Different number of aliases
                  level << destinationKey
                  level << destinationValue
                end
              elsif (destinationValue.is_a?(Psych::Nodes::Alias)) then
                # Sequence of aliases overriden by single alias
                level << destinationKey
                level << destinationValue
              else
                # Bad data
                # TODO Handle this
              end
            elsif (sourceValue.is_a?(Psych::Nodes::Alias)) then
              if (destinationValue.is_a?(Psych::Nodes::Sequence)) then
                # Single alias overriden by sequence of aliases
                level << destinationKey
                level << destinationValue
              elsif (destinationValue.is_a?(Psych::Nodes::Alias)) then
                # Compare aliases
                if (sourceValue.anchor != destinationValue.anchor || (includeAnchorDependencies && @modified_anchors.include?(destinationValue.anchor))) then
                  # Different aliases
                  level << destinationKey
                  level << destinationValue
                end
              else
                # Bad data
                # TODO Handle this
              end
            else
              # Bad data
              # TODO Handle this
            end
          elsif (destinationValue.is_a?(Psych::Nodes::Mapping)) then
            childLevel = processLevel(sourceValue.children, destinationValue.children, includeAnchorDependencies)

            if (childLevel.length > 0) then
              newMapping = Psych::Nodes::Mapping.new(destinationValue.anchor, destinationValue.tag, destinationValue.implicit, destinationValue.style)
              newMapping.children.push(*childLevel)

              level << destinationKey
              level << newMapping

              if (destinationValue.anchor != nil) then
                @modified_anchors << destinationValue.anchor
              end
            end
          elsif (destinationValue.is_a?(Psych::Nodes::Scalar)) then
            if (sourceValue.is_a?(Psych::Nodes::Scalar) && (destinationValue.value != sourceValue.value)) then
              level << destinationKey
              level << destinationValue

              if destinationValue.anchor != nil then
                @modified_anchors << destinationValue.anchor
              end
            elsif (!sourceValue.is_a?(Psych::Nodes::Alias || (includeAnchorDependencies && @modified_anchors.include?(destinationValue.anchor)))) then
              level << destinationKey
              level << destinationValue
            end
          elsif (destinationValue.is_a?(Psych::Nodes::Alias)) then
            if (sourceValue.is_a?(Psych::Nodes::Alias) && (destinationValue.anchor != sourceValue.anchor)) then
              level << destinationKey
              level << destinationValue
            elsif (sourceValue.is_a?(Psych::Nodes::Scalar)) then
              level << destinationKey
              level << destinationValue
            end
          end
        end
      }

      if (includeAnchorDependencies)
        # Find source pairs where value is alias that don't exist in destination
        # Look for aliases whose anchor was modified
        sourceChildren.find_all {|i|
          i[1].is_a?(Psych::Nodes::Alias) &&
          !i[1].anchor.nil? &&
          @modified_anchors.include?(i[1].anchor)
        }.each {|sp|
          dPair = destinationChildren.find_all {|i| i[0].value == sp[0].value}.last

          if (dPair == nil) then
            level << sp[0]
            level << sp[1]
          end
        }
      end

      level
    end

    def processModifiedAnchors(s, anchors)
      level = []

      # Split into key/value pairs
      sourceChildren = s.each_slice(2).to_a

      sourceChildren.each {|sourcePair|
        sourceKey = sourcePair[0]
        sourceValue = sourcePair[1]

        # Check if merge key
        if (sourceKey.value == "<<") then
          # Check if in modified_anchors

          if (sourceValue.is_a?(Psych::Nodes::Sequence)) then
            # Check each anchor in sequence
            aliases = sourceValue.children.find_all {|a| anchors.include?(a.anchor)}

            if (aliases.length > 0) then
              if (aliases.length == 1) then
                level << sourceKey
                level << aliases[0]
              else
                newSequence = Psych::Nodes::Sequence.new(sourceValue.anchor, sourceValue.tag, sourceValue.implicit, sourceValue.style)
                newSequence.children.push(*aliases)

                level << sourceKey
                level << newSequence
              end
            end
          else
            if (anchors.include?(sourceValue.anchor)) then
              # Add the merge key and include in the level
              level << sourceKey
              level << sourceValue
            end
          end

          next
        elsif (sourceValue.is_a?(Psych::Nodes::Mapping)) then
          childLevel = processModifiedAnchors(sourceValue.children, anchors)

          if (childLevel.length > 0) then
            newMapping = Psych::Nodes::Mapping.new(sourceValue.anchor, sourceValue.tag, sourceValue.implicit, sourceValue.style)
            newMapping.children.push(*childLevel)

            level << sourceKey
            level << newMapping

            # Add new anchors that are located
            if (sourceValue.anchor != nil) then
              @modified_anchors << sourceValue.anchor
            end
          end
        elsif (sourceValue.is_a?(Psych::Nodes::Alias) && anchors.include?(sourceValue.anchor)) then
            # Add the merge key and include in the level
            level << sourceKey
            level << sourceValue
        end
      }

      level
    end

    def compare_files(sourceFilePath, destinationFilePath, includeAnchorDependencies = false)
      sourceFile = File.open(sourceFilePath, "r")
      differenceFile = File.open(destinationFilePath, "r")

      begin
        result = compare(sourceFile, differenceFile, includeAnchorDependencies)
      ensure
        sourceFile.close
        differenceFile.close
      end

      result
    end

    def compare(source, destination, includeAnchorDependencies = false)
      @source_anchors = {}
      @modified_anchors = []

      sourceDocument = YAML.parse(source)
      destinationDocument = YAML.parse(destination)

      # Flatten merge keys for older ArchivesSpace files
      sourceRootLevel = YAMLTools.flatten_merge_keys(sourceDocument.root.children)
      destinationRootLevel = YAMLTools.flatten_merge_keys(destinationDocument.root.children)

      @differences = processLevel(sourceRootLevel, destinationRootLevel, includeAnchorDependencies)

      if (includeAnchorDependencies) then
        @current_modified_anchors = []

        combiner = Combiner.new

        loop do
          @current_modified_anchors = @modified_anchors.clone
          @modified_anchors = []
          modified_anchor_additions = processModifiedAnchors(sourceRootLevel, @current_modified_anchors)

          if (modified_anchor_additions.length > 0) then
            mergedDifferences = combiner.combine_levels(@differences, modified_anchor_additions)
            @differences = mergedDifferences
          end

          break if (@current_modified_anchors.length == 0)
        end
      end

      if (@differences.length > 0) then
        output = YAMLTools.createDocument(@differences)
      else
        output = ''
      end

      output
    end
  end
end
