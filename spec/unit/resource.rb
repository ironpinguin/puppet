#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/resource'

describe Puppet::Resource do
    [:catalog, :file, :line].each do |attr|
        it "should have an #{attr} attribute" do
            resource = Puppet::Resource.new("file", "/my/file")
            resource.should respond_to(attr)
            resource.should respond_to(attr.to_s + "=")
        end
    end

    describe "when initializing" do
        it "should require the type and title" do
            lambda { Puppet::Resource.new }.should raise_error(ArgumentError)
        end

        it "should create a resource reference with its type and title" do
            ref = Puppet::ResourceReference.new("file", "/f")
            Puppet::ResourceReference.expects(:new).with("file", "/f").returns ref
            Puppet::Resource.new("file", "/f")
        end

        it "should allow setting of parameters" do
            Puppet::Resource.new("file", "/f", :noop => true)[:noop].should be_true
        end

        it "should tag itself with its type" do
            Puppet::Resource.new("file", "/f").should be_tagged("file")
        end

        it "should tag itself with its title if the title is a valid tag" do
            Puppet::Resource.new("file", "bar").should be_tagged("bar")
        end

        it "should not tag itself with its title if the title is a not valid tag" do
            Puppet::Resource.new("file", "/bar").should_not be_tagged("/bar")
        end
    end

    it "should use the resource reference to determine its type" do
        ref = Puppet::ResourceReference.new("file", "/f")
        Puppet::ResourceReference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:type).returns "mytype"
        resource.type.should == "mytype"
    end

    it "should use its resource reference to determine its title" do
        ref = Puppet::ResourceReference.new("file", "/f")
        Puppet::ResourceReference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:title).returns "mytitle"
        resource.title.should == "mytitle"
    end

    it "should use its resource reference to produce its canonical reference string" do
        ref = Puppet::ResourceReference.new("file", "/f")
        Puppet::ResourceReference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:to_s).returns "Foo[bar]"
        resource.ref.should == "Foo[bar]"
    end

    it "should be taggable" do
        Puppet::Resource.ancestors.should be_include(Puppet::Util::Tagging)
    end

    describe "when managing parameters" do
        before do
            @resource = Puppet::Resource.new("file", "/my/file")
        end

        it "should allow setting and retrieving of parameters" do
            @resource[:foo] = "bar"
            @resource[:foo].should == "bar"
        end

        it "should canonicalize retrieved parameter names to treat symbols and strings equivalently" do
            @resource[:foo] = "bar"
            @resource["foo"].should == "bar"
        end

        it "should canonicalize set parameter names to treat symbols and strings equivalently" do
            @resource["foo"] = "bar"
            @resource[:foo].should == "bar"
        end

        it "should be able to iterate over parameters" do
            @resource[:foo] = "bar"
            @resource[:fee] = "bare"
            params = {}
            @resource.each do |key, value|
                params[key] = value
            end
            params.should == {:foo => "bar", :fee => "bare"}
        end

        it "should include Enumerable" do
            @resource.class.ancestors.should be_include(Enumerable)
        end

        it "should have a method for testing whether a parameter is included" do
            @resource[:foo] = "bar"
            @resource.should be_has_key(:foo)
            @resource.should_not be_has_key(:eh)
        end

        it "should have a method for providing the number of parameters" do
            @resource[:foo] = "bar"
            @resource.length.should == 1
        end

        it "should have a method for deleting parameters" do
            @resource[:foo] = "bar"
            @resource.delete(:foo)
            @resource[:foo].should be_nil
        end

        it "should have a method for testing whether the parameter list is empty" do
            @resource.should be_empty
            @resource[:foo] = "bar"
            @resource.should_not be_empty
        end
    end

    describe "when serializing" do
        before do
            @resource = Puppet::Resource.new("file", "/my/file")
            @resource["one"] = "test"
            @resource["two"] = "other"
        end

        it "should be able to be dumped to yaml" do
            proc { YAML.dump(@resource) }.should_not raise_error
        end

        it "should produce an equivalent yaml object" do
            text = YAML.dump(@resource)

            newresource = YAML.load(text)
            newresource.title.should == @resource.title
            newresource.type.should == @resource.type
            %w{one two}.each do |param|
                newresource[param].should == @resource[param]
            end
        end
    end

    describe "when converting to a RAL resource" do
        before do
            @resource = Puppet::Resource.new("file", "/my/file")
            @resource["one"] = "test"
            @resource["two"] = "other"
        end

        it "should use the resource type's :create method to create the resource if the resource is of a builtin type" do
            type = mock 'resource type'
            type.expects(:create).with(@resource).returns(:myresource)
            Puppet::Type.expects(:type).with(@resource.type).returns(type)
            @resource.to_ral.should == :myresource
        end

        it "should convert to a component instance if the resource type is not of a builtin type" do
            component = mock 'component type'
            Puppet::Type::Component.expects(:create).with(@resource).returns "meh"

            Puppet::Type.expects(:type).with(@resource.type).returns(nil)
            @resource.to_ral.should == "meh"
        end
    end

    it "should be able to convert itself to Puppet code" do
        Puppet::Resource.new("one::two", "/my/file").should respond_to(:to_manifest)
    end

    describe "when converting to puppet code" do
        before do
            @resource = Puppet::Resource.new("one::two", "/my/file", :noop => true, :foo => %w{one two})
        end

        it "should print the type and title" do
            @resource.to_manifest.should be_include("one::two { '/my/file':\n")
        end

        it "should print each parameter, with the value single-quoted" do
            @resource.to_manifest.should be_include("    noop => 'true'")
        end

        it "should print array values appropriately" do
            @resource.to_manifest.should be_include("    foo => ['one','two']")
        end
    end
end
