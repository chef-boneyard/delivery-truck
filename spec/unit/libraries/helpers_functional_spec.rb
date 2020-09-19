require 'spec_helper'

describe DeliveryTruck::Helpers::Functional do
  describe '.has_kitchen_tests?' do
    context 'when .kitchen.docker.yml file is present' do
      before do
        allow(File).to receive(:exist?).with('/tmp/cookbook/.kitchen.docker.yml').and_return(true)
      end

      it 'returns true' do
        expect(DeliveryTruck::Helpers::Functional.has_kitchen_tests?('/tmp/cookbook')).to eql true
      end
    end

    context 'when .kitchen.docker.yml file is missing' do
      before do
        allow(File).to receive(:exist?).with('/tmp/cookbook/.kitchen.docker.yml').and_return(false)
      end

      it 'returns false' do
        expect(DeliveryTruck::Helpers::Functional.has_kitchen_tests?('/tmp/cookbook')).to eql false
      end
    end
  end
end
