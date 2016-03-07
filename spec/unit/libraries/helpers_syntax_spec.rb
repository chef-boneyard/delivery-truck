require 'spec_helper'

module DeliverySugar
  class Change
  end
end

describe DeliveryTruck::Helpers::Syntax do

  describe '.bumped_version?' do
    let(:node) { double("node") }
    let(:workspace) { '/tmp/repo' }
    let(:pipeline) { 'master' }
    let(:relative_path) { '.' }

    let(:base_version) { '0.0.1' }
    let(:base_metadata) { double('metadata', name: 'julia', version: base_version) }

    let(:current_version) { '0.0.1' }
    let(:current_metadata) { double('metadata', name: 'julia', version: current_version) }

    let(:sugar_change) { double('delivery sugar change',
                                workspace_repo: workspace,
                                changed_files: changed_files,
                                pipeline: pipeline,
                                merge_sha: merge_sha) }

    before do
      allow(DeliverySugar::Change).to receive(:new).and_return(sugar_change)
      allow(sugar_change).to receive(:cookbook_metadata)
        .with(File.expand_path(relative_path, workspace)).and_return(current_metadata)
    end

    context 'with an unmerged change' do
      let(:merge_sha) { '' }

      before do
        allow(sugar_change).to receive(:cookbook_metadata)
          .with(relative_path, 'origin/master').and_return(base_metadata)
      end

      context 'when root cookbook was updated' do
        let(:changed_files) { ['README.md', 'recipes/default.rb', 'metadata.rb'] }

        context 'without version bump' do
          let(:current_version) { '0.0.1' }

          it 'returns false' do
            expect(described_class.bumped_version?(workspace, node)).to eql false
          end
        end

        context 'with version bump' do
          let(:current_version) { '0.0.2' }

          it 'returns true' do
            expect(described_class.bumped_version?(workspace, node)).to eql true 
          end
        end
      end

      context 'when non-cookbook file in root cookbook was updated' do
        let(:changed_files) { ['README.md'] }

        it 'returns true' do
          expect(described_class.bumped_version?(workspace, node)).to eql true
        end
      end

      context 'when non-cookbook file in cookbooks directory was updated' do
        let(:changed_files) { ['cookbooks/julia/README.md'] }
        let(:relative_path) { 'cookbooks/julia' }

        it 'returns true' do
          expect(described_class.bumped_version?(workspace, node)).to eql true
        end
      end

      context 'when cookbook in cookbooks directory was updated' do
        let(:changed_files) { ['cookbooks/julia/README.md', 'cookbooks/julia/recipes/default.rb', 'cookbooks/julia/metadata.rb'] }
        let(:relative_path) { 'cookbooks/julia' }

        context 'without version bump' do
          let(:current_version) { '0.0.1' }

          it 'returns false' do
            expect(described_class.bumped_version?("#{workspace}/#{relative_path}", node)).to eql false
          end
        end

        context 'with version bump' do
          let(:current_version) { '0.0.2' }

          it 'returns true' do
            expect(described_class.bumped_version?("#{workspace}/#{relative_path}", node)).to eql true
          end
        end
      end
    end

    context 'with a merged change' do
      let(:merge_sha) { 'abcdfakefake' }

      before do
        allow(sugar_change).to receive(:cookbook_metadata)
          .with(relative_path, 'abcdfakefake~1').and_return(base_metadata)
      end

      context 'when root cookbook was updated' do
        let(:changed_files) { ['README.md', 'recipes/default.rb', 'metadata.rb'] }

        context 'without version bump' do
          let(:current_version) { '0.0.1' }

          it 'returns false' do
            expect(described_class.bumped_version?(workspace, node)).to eql false
          end
        end

        context 'with version bump' do
          let(:current_version) { '0.0.2' }

          it 'returns true' do
            expect(described_class.bumped_version?(workspace, node)).to eql true 
          end
        end
      end

      context 'when non-cookbook file in root cookbook was updated' do
        let(:changed_files) { ['README.md'] }

        it 'returns true' do
          expect(described_class.bumped_version?(workspace, node)).to eql true
        end
      end

      context 'when non-cookbook file in cookbooks directory was updated' do
        let(:changed_files) { ['cookbooks/julia/README.md'] }
        let(:relative_path) { 'cookbooks/julia' }

        it 'returns true' do
          expect(described_class.bumped_version?(workspace, node)).to eql true
        end
      end

      context 'when cookbook in cookbooks directory was updated' do
        let(:changed_files) { ['cookbooks/julia/README.md', 'cookbooks/julia/recipes/default.rb', 'cookbooks/julia/metadata.rb'] }
        let(:relative_path) { 'cookbooks/julia' }

        context 'without version bump' do
          let(:current_version) { '0.0.1' }

          it 'returns false' do
            expect(described_class.bumped_version?("#{workspace}/#{relative_path}", node)).to eql false
          end
        end

        context 'with version bump' do
          let(:current_version) { '0.0.2' }

          it 'returns true' do
            expect(described_class.bumped_version?("#{workspace}/#{relative_path}", node)).to eql true
          end
        end
      end
    end
  end
end
