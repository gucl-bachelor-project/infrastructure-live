require 'spec_helper'

set :backend, :exec

describe "Local" do
    describe command('terraform --version') do
        its(:exit_status) { should eq 0 }
    end

    describe port(80) do
        it { should be_listening }
    end
end
