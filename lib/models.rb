# frozen_string_literal: true

require "sequel"
require "fileutils"

DB_PATH = ENV.fetch("HIVEHUB_DB", File.expand_path("../db/hivehub.sqlite3", __dir__))
FileUtils.mkdir_p(File.dirname(DB_PATH))
DB = Sequel.sqlite(DB_PATH)
DB.run("PRAGMA foreign_keys = ON")

DB.create_table? :users do
  primary_key :id
  String :username, unique: true
  String :password_hash
  String :github_uid, unique: true
  String :display_name, null: false
  Time :created_at
end

DB.create_table? :campaigns do
  primary_key :id
  foreign_key :user_id, :users, null: false, on_delete: :cascade
  String :name, null: false
  String :description
  Time :created_at
end

DB.create_table? :zones do
  primary_key :id
  foreign_key :campaign_id, :campaigns, null: false, on_delete: :cascade
  String :name, null: false
  Integer :season, null: false
  String :description
  Time :archived_at
  Time :created_at
end

DB.create_table? :gangs do
  primary_key :id
  foreign_key :campaign_id, :campaigns, null: false, on_delete: :cascade
  String :name, null: false
  String :gang_type, null: false
  String :color, null: false
  Time :created_at
end

DB.create_table? :turfs do
  primary_key :id
  foreign_key :zone_id, :zones, null: false, on_delete: :cascade
  Integer :q, null: false
  Integer :r, null: false
  String :name, null: false
  String :description
  foreign_key :gang_id, :gangs, on_delete: :set_null
  foreign_key :home_gang_id, :gangs, on_delete: :set_null
  Time :created_at
  unique %i[zone_id q r]
end

# Lightweight migration for databases created before season archiving.
DB.alter_table(:zones) { add_column :archived_at, Time } unless DB[:zones].columns.include?(:archived_at)

class User < Sequel::Model
  one_to_many :campaigns
end

class Campaign < Sequel::Model
  many_to_one :user
  one_to_many :zones, order: :season
  one_to_many :gangs, order: :created_at

  # Latest non-archived season; new gangs get their home turf here.
  def latest_zone = zones_dataset.where(archived_at: nil).order(Sequel.desc(:season)).first
end

class Zone < Sequel::Model
  many_to_one :campaign
  one_to_many :turfs

  def archived? = !archived_at.nil?
end

class Gang < Sequel::Model
  many_to_one :campaign
end

class Turf < Sequel::Model(:turfs)
  many_to_one :zone
  many_to_one :gang
end
