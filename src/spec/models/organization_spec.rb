#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'spec_helper'
require 'models/model_spec_helper'

describe Organization do

  before(:each) do
    Resources::Candlepin::Owner.stub!(:create_user).and_return(true)
    Resources::Candlepin::Owner.should_receive(:create).at_least(:once).and_return({})
    disable_env_orchestration
    @organization = Organization.create(:name => 'test_organization', :label=>'test_organization')
  end

  context "organization validation" do
    specify { Organization.new(:name => 'name', :label => 'org').should be_valid }
    specify { Organization.new(:name => 'name', :label => 'with_underscore').should be_valid }
    specify { Organization.new(:name => 'name', :label => 'With_Capital_letter').should be_valid }
    specify { Organization.new(:name => 'name', :label => 'with_number').should be_valid }
    specify { Organization.new(:name => 'name', :label => 'with\'space').should_not be_valid }
    specify { Organization.new(:name => 'o', :label => 'o').should be_valid }
    # creates :label from name
    specify { Organization.new(:name => 'without label').should be_valid }
    specify { Organization.new(:label => 'without_name').should_not be_valid }
    specify { Organization.new(:label => 'without_name').should_not be_valid }
  end

  context "create an organization" do
    specify {@organization.name.should == 'test_organization'}
    specify {@organization.label.should == 'test_organization'}
    specify {@organization.library.should_not be_nil}
    specify {@organization.redhat_provider.should_not be_nil}
    specify {@organization.environments.should be_empty}
    specify {Organization.where(:name => @organization.name).size.should == 1}
    specify {Organization.where(:name => @organization.name).first.should == @organization}
    
    it "should complain on duplicate name" do
      lambda{Organization.create!(:name => @organization.name, :label => @organization.name + "foo")}.should raise_error
    end
    it "should complain on duplicate label" do
      lambda{Organization.create!(:name => @organization.name + "foo", :label =>@organization.name)}.should raise_error
    end

  end

  context "update an organization" do
    
    it "can update the name" do
      new_name = @organization.name + "1"
      @organization = Organization.update(@organization.id, {:name => new_name})
      @organization.name.should == new_name
    end

  end
  

  context "delete an organization" do
    before do
      Resources::Candlepin::Owner.should_receive(:destroy).at_least(:once).and_return({})
    end

    it "can delete the org" do
      id = @organization.id
      @organization.destroy
      
      lambda{Organization.find(id)}.should raise_error(ActiveRecord::RecordNotFound)
    end

    it "can delete the org and envs are deleted" do
      org_id = @organization.id
      
      env_name = "prod"      
      @env = KTEnvironment.new(:name=>env_name, :label=> env_name, :library => false, :prior => @organization.library)
      @organization.environments << @env
      @env.save!
      
      @organization.destroy
      
      lambda{Organization.find(org_id)}.should raise_error(ActiveRecord::RecordNotFound)
      #@env.should_receive(:destroy).at_least(:once)
      KTEnvironment.where(:name => env_name).all.should be_empty
    end
    
    
    it "can delete the org and env of a different org exist" do
      env_name = "prod"
      
      @org2 = Organization.create!(:name=>"foobar", :label=> "foobar")

      @env1 = KTEnvironment.new(:name=>env_name, :label=> env_name, :organization => @organization, :prior => @organization.library)
      @organization.environments << @env1
      @env1.save!    
      
      @env2 = KTEnvironment.new(:name=>env_name, :label=> env_name, :organization => @org2, :prior => @organization.library)
      @org2.environments << @env2
      @env2.save!
      
      id1 = @organization.id
      @organization.destroy
      lambda{Organization.find(id1)}.should raise_error(ActiveRecord::RecordNotFound)

      KTEnvironment.where(:name => env_name).first.should == @env2
      KTEnvironment.where(:name => env_name).size.should == 1
    end

    it "can delete an org where there is a full environment path" do
       dev = KTEnvironment.create!(:name=>"Dev", :label=> "Dev", :organization => @organization, :prior => @organization.library)
       qa = KTEnvironment.create!(:name=>"QA", :label=> "QA", :organization => @organization, :prior => dev)
       prod =  KTEnvironment.create!(:name=>"prod", :label=> "prod", :organization => @organization, :prior => qa)
       @organization = @organization.reload
       @organization.destroy
       lambda{Organization.find(@organization.id)}.should raise_error(ActiveRecord::RecordNotFound)
       KTEnvironment.where(:name =>'Dev').size.should == 0 
    end

  end
end
