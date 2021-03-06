#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/monkey_patches'


describe Symbol do
  it "should return self from #intern" do
    symbol = :foo
    symbol.should equal symbol.intern
  end
end


describe "yaml deserialization" do
  it "should call yaml_initialize when deserializing objects that have that method defined" do
    class Puppet::TestYamlInitializeClass
      attr_reader :foo

      def yaml_initialize(tag, var)
        var.should == {'foo' => 100}
        instance_variables.should == []
        @foo = 200
      end
    end

    obj = YAML.load("--- !ruby/object:Puppet::TestYamlInitializeClass\n  foo: 100")
    obj.foo.should == 200
  end

  it "should not call yaml_initialize if not defined" do
    class Puppet::TestYamlNonInitializeClass
      attr_reader :foo
    end

    obj = YAML.load("--- !ruby/object:Puppet::TestYamlNonInitializeClass\n  foo: 100")
    obj.foo.should == 100
  end
end

describe IO do
  include PuppetSpec::Files

  let(:file) { tmpfile('io-binary') }
  let(:content) { "\x01\x02\x03\x04" }

  describe "::binwrite" do
    it "should write in binary mode" do
      IO.binwrite(file, content).should == content.length
      File.open(file, 'rb') {|f| f.read.should == content }
    end

    (0..10).each do |offset|
      it "should write correctly using an offset of #{offset}" do
        IO.binwrite(file, content, offset).should == content.length
        File.open(file, 'rb') {|f| f.read.should == ("\x00" * offset) + content }
      end
    end

    context "truncation" do
      let :input do "welcome to paradise, population ... YOU!" end
      before :each do IO.binwrite(file, input) end

      it "should truncate if no offset is given" do
        IO.binwrite(file, "boo").should == 3
        File.read(file).should == "boo"
      end

      (0..10).each do |offset|
        it "should not truncate if an offset of #{offset} is given" do
          expect = input.dup
          expect[offset, 3] = "BAM"

          IO.binwrite(file, "BAM", offset).should == 3
          File.read(file).should == expect
        end
      end

      it "should pad with NULL bytes if writing past EOF without truncate" do
        expect = input + ("\x00" * 4) + "BAM"
        IO.binwrite(file, "BAM", input.length + 4).should == 3
        File.read(file).should == expect
      end
    end

    it "should raise an error if the directory containing the file doesn't exist" do
      expect { IO.binwrite('/path/does/not/exist', 'foo') }.to raise_error(Errno::ENOENT)
    end
  end
end

describe Range do
  def do_test( range, other, expected )
    result = range.intersection(other)
    result.should == expected
  end

  it "should return expected ranges for iterable things" do
    iterable_tests = {
      1  .. 4   => nil,          # before
      11 .. 15  => nil,          # after
      1  .. 6   => 5  ..  6,     # overlap_begin
      9  .. 15  => 9  ..  10,    # overlap_end
      1  .. 5   => 5  ..  5,     # overlap_begin_edge
      10 .. 15  => 10 ..  10,    # overlap_end_edge
      5  .. 10  => 5  ..  10,    # overlap_all
      6  .. 9   => 6  ..  9,     # overlap_inner

      1 ... 5   => nil,          # before             (exclusive range)
      1 ... 7   => 5  ... 7,     # overlap_begin      (exclusive range)
      1 ... 6   => 5  ... 6,     # overlap_begin_edge (exclusive range)
      5 ... 11  => 5  ..  10,    # overlap_all        (exclusive range)
      6 ... 10  => 6  ... 10,    # overlap_inner      (exclusive range)
    }

    iterable_tests.each do |other, expected|
      do_test( 5..10, other, expected )
      do_test( other, 5..10, expected )
    end
  end

  it "should return expected ranges for noniterable things" do
    inclusive_base_case = {
      1.to_f  .. 4.to_f   => nil,                   # before
      11.to_f .. 15.to_f  => nil,                   # after
      1.to_f  .. 6.to_f   => 5.to_f  ..  6.to_f,    # overlap_begin
      9.to_f  .. 15.to_f  => 9.to_f  ..  10.to_f,   # overlap_end
      1.to_f  .. 5.to_f   => 5.to_f  ..  5.to_f,    # overlap_begin_edge
      10.to_f .. 15.to_f  => 10.to_f ..  10.to_f,   # overlap_end_edge
      5.to_f  .. 10.to_f  => 5.to_f  ..  10.to_f,   # overlap_all
      6.to_f  .. 9.to_f   => 6.to_f  ..  9.to_f,    # overlap_inner

      1.to_f ... 5.to_f   => nil,                   # before             (exclusive range)
      1.to_f ... 7.to_f   => 5.to_f  ... 7.to_f,    # overlap_begin      (exclusive range)
      1.to_f ... 6.to_f   => 5.to_f  ... 6.to_f,    # overlap_begin_edge (exclusive range)
      5.to_f ... 11.to_f  => 5.to_f  ..  10.to_f,   # overlap_all        (exclusive range)
      6.to_f ... 10.to_f  => 6.to_f  ... 10.to_f,   # overlap_inner      (exclusive range)
    }

    inclusive_base_case.each do |other, expected|
      do_test( 5.to_f..10.to_f, other, expected )
      do_test( other, 5.to_f..10.to_f, expected )
    end

    exclusive_base_case = {
      1.to_f  .. 4.to_f   => nil,                   # before
      11.to_f .. 15.to_f  => nil,                   # after
      1.to_f  .. 6.to_f   => 5.to_f  ..  6.to_f,    # overlap_begin
      9.to_f  .. 15.to_f  => 9.to_f  ... 10.to_f,   # overlap_end
      1.to_f  .. 5.to_f   => 5.to_f  ..  5.to_f,    # overlap_begin_edge
      10.to_f .. 15.to_f  => nil,                   # overlap_end_edge
      5.to_f  .. 10.to_f  => 5.to_f  ... 10.to_f,   # overlap_all
      6.to_f  .. 9.to_f   => 6.to_f  ..  9.to_f,    # overlap_inner

      1.to_f ... 5.to_f   => nil,                   # before             (exclusive range)
      1.to_f ... 7.to_f   => 5.to_f  ... 7.to_f,    # overlap_begin      (exclusive range)
      1.to_f ... 6.to_f   => 5.to_f  ... 6.to_f,    # overlap_begin_edge (exclusive range)
      5.to_f ... 11.to_f  => 5.to_f  ... 10.to_f,   # overlap_all        (exclusive range)
      6.to_f ... 10.to_f  => 6.to_f  ... 10.to_f,   # overlap_inner      (exclusive range)
    }

    exclusive_base_case.each do |other, expected|
      do_test( 5.to_f...10.to_f, other, expected )
      do_test( other, 5.to_f...10.to_f, expected )
    end
  end
end

describe OpenSSL::SSL::SSLContext do
  it 'disables SSLv2 via the SSLContext#options bitmask' do
    (subject.options & OpenSSL::SSL::OP_NO_SSLv2).should == OpenSSL::SSL::OP_NO_SSLv2
  end

  it 'disables SSLv3 via the SSLContext#options bitmask' do
    (subject.options & OpenSSL::SSL::OP_NO_SSLv3).should == OpenSSL::SSL::OP_NO_SSLv3
  end

  it 'explicitly disable SSLv2 ciphers using the ! prefix so they cannot be re-added' do
    cipher_str = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]
    cipher_str.split(':').should include('!SSLv2')
  end

  it 'does not exclude SSLv3 ciphers shared with TLSv1' do
    cipher_str = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]
    cipher_str.split(':').should_not include('!SSLv3')
  end

  it 'sets parameters on initialization' do
    described_class.any_instance.expects(:set_params)
    subject
  end

  it 'has no ciphers with version SSLv2 enabled' do
    ciphers = subject.ciphers.select do |name, version, bits, alg_bits|
      /SSLv2/.match(version)
    end
    ciphers.should be_empty
  end
end


describe OpenSSL::X509::Store, :if => Puppet::Util::Platform.windows? do
  let(:store) { described_class.new }
  let(:cert)  { OpenSSL::X509::Certificate.new(File.read(my_fixture('x509.pem'))) }

  def with_root_certs(certs)
    Puppet::Util::Windows::RootCerts.expects(:instance).returns(certs)
  end

  it "adds a root cert to the store" do
    with_root_certs([cert])

    store.set_default_paths
  end

  it "ignores duplicate root certs" do
    with_root_certs([cert, cert])

    store.expects(:add_cert).with(cert).once

    store.set_default_paths
  end

  it "warns when adding a certificate that already exists" do
    with_root_certs([cert])
    store.add_cert(cert)

    store.expects(:warn).with('Failed to add /DC=com/DC=microsoft/CN=Microsoft Root Certificate Authority')

    store.set_default_paths
  end

  it "raises when adding an invalid certificate" do
    with_root_certs(['notacert'])

    expect {
      store.set_default_paths
    }.to raise_error(TypeError)
  end
end

describe SecureRandom do
  it 'generates a properly formatted uuid' do
    SecureRandom.uuid.should =~ /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i
  end
end
