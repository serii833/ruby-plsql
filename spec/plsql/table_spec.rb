require File.dirname(__FILE__) + '/../spec_helper'

describe "Table" do
  before(:all) do
    plsql.connection = get_connection
    plsql.connection.autocommit = false
    plsql.execute <<-SQL
      CREATE TABLE test_employees (
        employee_id   NUMBER(15),
        first_name    VARCHAR2(50),
        last_name     VARCHAR2(50),
        hire_date     DATE
      )
    SQL

    plsql.connection.exec <<-SQL
      CREATE OR REPLACE TYPE t_address AS OBJECT (
        street    VARCHAR2(50),
        city      VARCHAR2(50),
        country   VARCHAR2(50)
      )
    SQL
    plsql.connection.exec <<-SQL
      CREATE OR REPLACE TYPE t_phone AS OBJECT (
        type            VARCHAR2(10),
        phone_number    VARCHAR2(50)
      )
    SQL
    plsql.connection.exec <<-SQL
      CREATE OR REPLACE TYPE t_phones AS VARRAY(10) OF T_PHONE
    SQL
    plsql.connection.exec <<-SQL
      CREATE TABLE test_employees2 (
        employee_id   NUMBER(15),
        first_name    VARCHAR2(50),
        last_name     VARCHAR2(50),
        hire_date     DATE,
        address       t_address,
        phones        t_phones
      )
    SQL
    @employees = (1..10).map do |i|
      {
        :employee_id => i,
        :first_name => "First #{i}",
        :last_name => "Last #{i}",
        :hire_date => Time.local(2000,01,i)
      }
    end
  end

  after(:all) do
    plsql.execute "DROP TABLE test_employees"
    plsql.execute "DROP TABLE test_employees2"
    plsql.execute "DROP TYPE t_phones"
    plsql.execute "DROP TYPE t_phone"
    plsql.execute "DROP TYPE t_address"
    plsql.logoff
  end

  after(:each) do
    plsql.rollback
  end

  describe "find" do

    it "should find existing table" do
      PLSQL::Table.find(plsql, :test_employees).should_not be_nil
    end

    it "should not find nonexisting table" do
      PLSQL::Table.find(plsql, :qwerty123456).should be_nil
    end

    it "should find existing table in schema" do
      plsql.test_employees.should be_a(PLSQL::Table)
    end

  end

  describe "synonym" do

    before(:all) do
      plsql.connection.exec "CREATE SYNONYM test_employees_synonym FOR hr.test_employees"
    end

    after(:all) do
      plsql.connection.exec "DROP SYNONYM test_employees_synonym" rescue nil
    end

    it "should find synonym to table" do
      PLSQL::Table.find(plsql, :test_employees_synonym).should_not be_nil
    end

    it "should find table using synonym in schema" do
      plsql.test_employees_synonym.should be_a(PLSQL::Table)
    end

  end

  describe "public synonym" do

    it "should find public synonym to table" do
      PLSQL::Table.find(plsql, :dual).should_not be_nil
    end

    it "should find table using public synonym in schema" do
      plsql.dual.should be_a(PLSQL::Table)
    end

  end

  describe "columns" do

    it "should get columns metadata for table" do
      plsql.test_employees.columns.should == {
        :employee_id =>
          {:position=>1, :data_type=>"NUMBER", :data_length=>22, :data_precision=>15, :data_scale=>0, :char_used=>nil, :type_owner=>nil, :type_name=>nil, :sql_type_name=>nil},
        :first_name =>
          {:position=>2, :data_type=>"VARCHAR2", :data_length=>50, :data_precision=>nil, :data_scale=>nil, :char_used=>"B", :type_owner=>nil, :type_name=>nil, :sql_type_name=>nil},
        :last_name =>
          {:position=>3, :data_type=>"VARCHAR2", :data_length=>50, :data_precision=>nil, :data_scale=>nil, :char_used=>"B", :type_owner=>nil, :type_name=>nil, :sql_type_name=>nil},
        :hire_date => 
          {:position=>4, :data_type=>"DATE", :data_length=>7, :data_precision=>nil, :data_scale=>nil, :char_used=>nil, :type_owner=>nil, :type_name=>nil, :sql_type_name=>nil}
      }
    end

    it "should get columns metadata for table with object columns" do
      plsql.test_employees2.columns.should == {
        :employee_id =>
          {:position=>1, :data_type=>"NUMBER", :data_length=>22, :data_precision=>15, :data_scale=>0, :char_used=>nil, :type_owner=>nil, :type_name=>nil, :sql_type_name=>nil},
        :first_name =>
          {:position=>2, :data_type=>"VARCHAR2", :data_length=>50, :data_precision=>nil, :data_scale=>nil, :char_used=>"B", :type_owner=>nil, :type_name=>nil, :sql_type_name=>nil},
        :last_name =>
          {:position=>3, :data_type=>"VARCHAR2", :data_length=>50, :data_precision=>nil, :data_scale=>nil, :char_used=>"B", :type_owner=>nil, :type_name=>nil, :sql_type_name=>nil},
        :hire_date => 
          {:position=>4, :data_type=>"DATE", :data_length=>7, :data_precision=>nil, :data_scale=>nil, :char_used=>nil, :type_owner=>nil, :type_name=>nil, :sql_type_name=>nil},
        :address => 
          {:position=>5, :data_type=>"OBJECT", :data_length=>nil, :data_precision=>nil, :data_scale=>nil, :char_used=>nil, :type_owner=>"HR", :type_name=>"T_ADDRESS", :sql_type_name=>"HR.T_ADDRESS"},
        :phones => 
          {:position=>6, :data_type=>"OBJECT", :data_length=>nil, :data_precision=>nil, :data_scale=>nil, :char_used=>nil, :type_owner=>"HR", :type_name=>"T_PHONES", :sql_type_name=>"HR.T_PHONES"}
      }
    end

  end

  describe "insert" do
    it "should insert a record in table" do
      plsql.test_employees.insert @employees.first
      plsql.test_employees.all.should == [@employees.first]
    end

    it "should insert array of records in table" do
      plsql.test_employees.insert @employees
      plsql.test_employees.all("ORDER BY employee_id").should == @employees
    end

  end

  describe "select" do
    before(:each) do
      plsql.test_employees.insert @employees
    end

    it "should select first record in table" do
      plsql.test_employees.select(:first, "ORDER BY employee_id").should == @employees.first
      plsql.test_employees.first("ORDER BY employee_id").should == @employees.first
    end

    it "should select all records in table" do
      plsql.test_employees.select(:all, "ORDER BY employee_id").should == @employees
      plsql.test_employees.all("ORDER BY employee_id").should == @employees
      plsql.test_employees.all(:order_by => :employee_id).should == @employees
    end

    it "should select record in table using WHERE condition" do
      plsql.test_employees.select(:first, "WHERE employee_id = :1", @employees.first[:employee_id]).should == @employees.first
      plsql.test_employees.first("WHERE employee_id = :1", @employees.first[:employee_id]).should == @employees.first
      plsql.test_employees.first(:employee_id => @employees.first[:employee_id]).should == @employees.first
    end

    it "should count records in table" do
      plsql.test_employees.select(:count).should == @employees.size
      plsql.test_employees.count.should == @employees.size
    end

    it "should count records in table using condition" do
      plsql.test_employees.select(:count, "WHERE employee_id <= :1", @employees[2][:employee_id]).should == 3
      plsql.test_employees.count("WHERE employee_id <= :1", @employees[2][:employee_id]).should == 3
    end

  end

  describe "update" do
    it "should update a record in table" do
      employee_id = @employees.first[:employee_id]
      plsql.test_employees.insert @employees.first
      plsql.test_employees.update :first_name => 'Test', :where => {:employee_id => employee_id}
      plsql.test_employees.first(:employee_id => employee_id)[:first_name].should == 'Test'
    end

    it "should update a record in table using String WHERE condition" do
      employee_id = @employees.first[:employee_id]
      plsql.test_employees.insert @employees
      plsql.test_employees.update :first_name => 'Test', :where => "employee_id = #{employee_id}"
      plsql.test_employees.first(:employee_id => employee_id)[:first_name].should == 'Test'
      # all other records should not be changed
      plsql.test_employees.all("WHERE employee_id > :1", employee_id) do |employee|
        employee[:first_name].should_not == 'Test'
      end
    end

    it "should update all records in table" do
      plsql.test_employees.insert @employees
      plsql.test_employees.update :first_name => 'Test'
      plsql.test_employees.all do |employee|
        employee[:first_name].should == 'Test'
      end
    end

  end

end