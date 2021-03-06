require 'spec_helper'

describe Puppet::Type.type(:firewalld_zone) do

  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true)
  end

  describe "type" do
    context 'with no params' do
      describe 'when validating attributes' do
        [
          :name
        ].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:param)
          end
        end

        [
          :target, :icmp_blocks, :sources, :purge_rich_rules, :purge_services, :purge_ports
        ].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:property)
          end
        end
      end
    end
  end


  ## Provider tests for the firewalld_zone type
  #
  describe "provider" do

    context "with standard parameters" do
      let(:resource) {
        described_class.new(
          :name => 'restricted',
          :target => '%%REJECT%%',
          :interfaces => ['eth0'],
          :icmp_blocks => [ 'redirect', 'router-advertisment' ],
          :sources    => ['192.168.2.2', '10.72.1.100'])
      }
      let(:provider) {
        resource.provider
      }

      it "should check if it exists" do
        provider.expects(:execute_firewall_cmd).with(['--get-zones'], nil).returns('public restricted')
        expect(provider.exists?).to be_truthy
      end

      it "should check if it doesnt exist" do
        provider.expects(:execute_firewall_cmd).with(['--get-zones'], nil).returns('public private')
        expect(provider.exists?).to be_falsey
      end

      it "should evalulate target" do
        provider.expects(:execute_firewall_cmd).with(['--get-target']).returns('%%REJECT%%')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it "should evalulate target correctly when not surrounded with %%" do
        provider.expects(:execute_firewall_cmd).with(['--get-target']).returns('REJECT')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it "should create" do
        provider.expects(:execute_firewall_cmd).with(['--new-zone', 'restricted'], nil)
        provider.expects(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])

        provider.expects(:icmp_blocks=).with(['redirect', 'router-advertisment'])

        provider.expects(:sources).returns([])
        provider.expects(:execute_firewall_cmd).with(['--add-source', '192.168.2.2'])
        provider.expects(:execute_firewall_cmd).with(['--add-source', '10.72.1.100'])

        provider.expects(:interfaces).returns([])
        provider.expects(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        provider.create
      end

      it "should remove" do
        provider.expects(:execute_firewall_cmd).with(['--delete-zone', 'restricted'], nil)
        provider.destroy
      end

      it "should set target" do
        provider.expects(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])
        provider.target=('%%REJECT%%')
      end

      it "should get interfaces" do
        provider.expects(:execute_firewall_cmd).with(['--list-interfaces'], 'restricted', false).returns("")
        provider.interfaces
      end

      it "should set interfaces" do
        provider.expects(:interfaces).returns(['eth1'])
        provider.expects(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        provider.expects(:execute_firewall_cmd).with(['--remove-interface', 'eth1'])
        provider.interfaces=(['eth0'])
      end

      it "should get sources" do
        provider.expects(:execute_firewall_cmd).with(['--list-sources']).returns("val val")
        expect(provider.sources).to eq(["val", "val"])
      end


      it "sources should always return in alphanumerical order" do
        provider.expects(:execute_firewall_cmd).with(['--list-sources']).returns("4.4.4.4/32 2.2.2.2/32 3.3.3.3/32")
        expect(provider.sources).to eq(["2.2.2.2/32", "3.3.3.3/32","4.4.4.4/32"])
      end

      it "should set sources" do
        provider.expects(:sources).returns(["valx"])
        provider.expects(:execute_firewall_cmd).with(['--add-source', 'valy'])
        provider.expects(:execute_firewall_cmd).with(['--remove-source', 'valx'])
        provider.sources=(['valy'])
      end

      it "should get icmp_blocks" do
        provider.expects(:execute_firewall_cmd).with(['--list-icmp-blocks']).returns("val")
        expect(provider.icmp_blocks).to eq(['val'])
      end

      it "should list icmp types" do
        provider.expects(:execute_firewall_cmd).with(['--get-icmptypes'], nil).returns("echo-reply echo-request")
        expect(provider.get_icmp_types).to eq(['echo-reply', 'echo-request'])
      end
    end

    context "when specifiying masquerade" do
      let(:resource) {
        described_class.new(
          :name => 'public',
          :ensure => :present,
          :masquerade => true,
        )
      }
      let(:provider) {
        resource.provider
      }

      it "should set masquerading" do
        provider.expects(:execute_firewall_cmd).with(['--add-masquerade'])
        provider.masquerade=(:true)
      end

      it "should disable masquerading" do
        provider.expects(:execute_firewall_cmd).with(['--remove-masquerade'])
        provider.masquerade=(:false)
      end

      it "should get masquerading state as false when not set" do
        provider.expects(:execute_firewall_cmd).with(['--query-masquerade'], 'public', true, false).returns("no\n")
        expect(provider.masquerade).to eq(:false)
      end
      it "should get masquerading state as true when set" do
        provider.expects(:execute_firewall_cmd).with(['--query-masquerade'], 'public', true, false).returns("yes\n")
        expect(provider.masquerade).to eq(:true)
      end

    end
  end
end
