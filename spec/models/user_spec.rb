# encoding: UTF-8
require 'spec_helper'

describe User do
  before  { @user = FactoryGirl.create(:user) }
  subject { @user }

  describe "attributes" do
    it { should accept_values_for(:login, 'first.last', 'abc', 'heinz_klein') }
    it { should_not accept_values_for(:login, '', nil) }
    it { should accept_values_for(:email, 'abc@example.org', 'admin@altimos.de', '', nil) }
    it { should_not accept_values_for(:email, 'abc', '@domain', 'user@', 'root@local') }
    it { should accept_values_for(:name, 'John Smith', 'Yung Heng', 'K. Müller')}
    it { should_not accept_values_for(:name, nil, '') }
    it { should be_logged }
    it { should_not be_admin }
    it { should_not be_internal }
    it { @user.language.should == I18n.locale.to_s }
    it { @user.time_zone.should == 'Berlin' }

    # reserved logins
    it { should_not accept_values_for(:login, 'anonymous', 'system')}

    it 'should have a unique login' do
      another_user = FactoryGirl.build(:user, :login => @user.login)
      another_user.login.should == @user.login
      another_user.should_not be_valid
      another_user.save.should be_false
    end

    it 'can be destroyed' do
      user = FactoryGirl.create(:user)
      user.destroy.should_not be_false
    end

    context 'when admin' do
      before  { @admin = FactoryGirl.create(:admin) }
      subject { @admin }

      it { should_not be_destructible }
      it('can not be destroyed') { @admin.destroy.should be_false }
    end
  end

  describe '@class' do
    # TODO: should be redesigned somehow
    context '#system' do
      before  { @sys = User.system }
      subject { @sys }

      it('should be a SystemUser') { should be_an SystemUser }
      it('should have reserved system login') { @sys.login.should == 'system' }
      it('should always return same instance') { should == User.system }
      it { should_not be_logged }
      it { should be_admin }
      it { should be_internal }
    end

    context '#anonymous' do
      before  { @anon = User.anonymous }
      subject { @anon }

      it('should be an AnonymousUser') { should be_an AnonymousUser }
      it('should have reserved anonymous login') { @anon.login.should == 'anonymous' }
      it('should always return same instance') { should == User.anonymous }
      it { should_not be_logged }
      it { should_not be_admin }
      it { should be_internal }
    end

    context '#current' do
      it 'returns Anonymous by default' do
        User.current = nil
        User.current.should be_an AnonymousUser
      end

      it 'stores a single user object' do
        user = FactoryGirl.create(:user)
        User.current = user

        User.current.should equal(user)
      end
    end
  end

  describe '@massassignment' do
    context 'when create' do
      subject { User.new }

      it do
        should have_safe_attributes(:login, :email, :name, :time_zone, :language)
      end

      it do
        should have_safe_attributes(:login, :email, :name, :time_zone, :language).
          as(FactoryGirl.create(:user), 'User')
      end

      it do
        should have_safe_attributes(:login, :email, :name, :time_zone, :language, :admin).
          as(FactoryGirl.create(:admin), 'Administrator').and_as(User.system, 'System')
      end
    end

    context 'when update' do
      before(:all) { @user = FactoryGirl.create(:user) }

      it do
        @user.should have_no_safe_attributes
      end

      it do
        another_user = FactoryGirl.create :user
        @user.should have_no_safe_attributes.as(another_user, '(another) User')
      end

      it do
        @user.should have_safe_attributes(:email, :name, :time_zone, :language).
          as(@user, 'himself')
      end

      it do
        admin = FactoryGirl.create :admin
        @user.should have_safe_attributes(:login, :email, :name, :time_zone, :language, :admin).
          as(admin, 'Administrator').and_as(User.system, 'System')
      end
    end
  end

  describe '@scopes' do
    context '#all' do
      it 'does not contain AnonymousUser or SystemUser' do
        User.anonymous # enforce that AnonymousUser and
        User.system    # SystemUser exist
        FactoryGirl.create(:user)

        User.all.should_not be_empty
        User.all.select { |u| u.login == 'anonymous' or u.login == 'system' }.should be_empty
      end
    end
  end

  context '@authorization' do
    context 'Anonymous' do
      subject { User.anonymous }
      before(:all) { @user = FactoryGirl.create(:user) }

      it { should_not be_able_to(:index, User, 'Users') }
      it { should_not be_able_to(:new, User, 'a User') }
      it { should_not be_able_to(:create, User, 'a User') }
      it { should_not be_able_to(:show, @user, 'a User') }
      it { should_not be_able_to(:edit, @user, 'a User') }
      it { should_not be_able_to(:update, @user, 'a User') }
      it { should_not be_able_to(:delete, @user, 'a User') }
      it { should_not be_able_to(:destroy, @user, 'a User') }
      it { should_not be_able_to(:show, User.anonymous, 'himself') }
      it { should_not be_able_to(:edit, User.anonymous, 'himself') }
      it { should_not be_able_to(:update, User.anonymous, 'himself') }
      it { should_not be_able_to(:delete, User.anonymous, 'himself') }
      it { should_not be_able_to(:destroy, User.anonymous, 'himself') }
    end
    context 'User' do
      before(:all) do
        @user  = FactoryGirl.create(:user)
        @user2 = FactoryGirl.create(:user)
      end
      subject { @user }

      it { should_not be_able_to(:index, User, 'Users') }
      it { should_not be_able_to(:new, User, 'a User') }
      it { should_not be_able_to(:create, User, 'a User') }
      it { should_not be_able_to(:show, @user2, 'a User') }
      it { should_not be_able_to(:edit, @user2, 'a User') }
      it { should_not be_able_to(:update, @user2, 'a User') }
      it { should_not be_able_to(:delete, @user2, 'a User') }
      it { should_not be_able_to(:destroy, @user2, 'a User') }
      it { should be_able_to(:show, @user, 'himself') }
      it { should_not be_able_to(:edit, @user, 'himself') }
      it { should_not be_able_to(:update, @user, 'himself') }
      it { should_not be_able_to(:delete, @user, 'himself') }
      it { should_not be_able_to(:destroy, @user, 'himself') }
    end
    context 'Administrator' do
      before(:all) do
        @admin  = FactoryGirl.create(:admin)
        @admin2 = FactoryGirl.create(:admin)
        @user   = FactoryGirl.create(:user)
      end
      subject { @admin }

      it { should be_able_to(:create, User, 'Users') }
      it { should be_able_to(:index, User, 'Users') }
      it { should be_able_to(:update, @user, 'a User') }
      it { should be_able_to(:show, @user, 'a User') }
      it { should be_able_to(:destroy, @user, 'a User') }
      it { should be_able_to(:update, @admin, 'himself') }
      it { should be_able_to(:show, @admin, 'himself') }
      it { should be_able_to(:update, @admin2, 'another Admin') }
      it { should be_able_to(:show, @admin2, 'another Admin') }
      it { should_not be_able_to(:destroy, @admin, 'himself') }
      it { should_not be_able_to(:destroy, @admin2, 'another Admin') }
    end
  end

  describe "identities" do
    subject { @user.identities }

    it { should_not be_empty }
  end
end