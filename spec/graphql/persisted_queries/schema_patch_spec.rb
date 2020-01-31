# frozen_string_literal: true

require "spec_helper"

require "digest"

RSpec.describe GraphQL::PersistedQueries::SchemaPatch do
  QueryType = Class.new(GraphQL::Schema::Object) do
    field :some_data, String, null: false

    def some_data
      "some value"
    end
  end

  TestErrorHandler = Class.new(GraphQL::PersistedQueries::ErrorHandlers::BaseErrorHandler) do
    attr_accessor :last_handled_error

    def call(error)
      self.last_handled_error = error
      raise error
    end
  end

  GraphqlSchema = Class.new(GraphQL::Schema) do
    use GraphQL::PersistedQueries, error_handler: TestErrorHandler.new({})

    query QueryType
  end

  let(:sha256) { Digest::SHA256.hexdigest(query) }

  def perform_request
    GraphqlSchema.execute(query, extensions: { "persistedQuery" => { "sha256Hash" => sha256 } })
  end

  subject(:response) do
    perform_request
  end

  context "when cache is cold" do
    let(:query) { nil }
    let(:sha256) { 1 }

    it "returns error" do
      expect(response[:errors]).to include(message: "PersistedQueryNotFound")
    end
  end

  context "when cache is warm" do
    before { perform_request }

    let(:query) do
      <<-GQL
        query {
          someData
        }
      GQL
    end

    it "returns data" do
      expect(response["data"]).to eq("someData" => "some value")
    end
  end

  context "when cache is unavailable" do
    let(:query) { nil }
    let(:sha256) { 1 }

    UnavailableStore = Class.new(GraphQL::PersistedQueries::StoreAdapters::BaseStoreAdapter) do
      def fetch_query(_)
        raise "Store unavailable"
      end

      def save_query(_, _)
        raise "Store unavailable"
      end
    end

    around do |test|
      original_store = GraphqlSchema.persisted_query_store
      GraphqlSchema.configure_persisted_query_store(UnavailableStore.new({}), {})
      test.run
      GraphqlSchema.configure_persisted_query_store(original_store, {})
    end

    it "calls the error handler" do
      # rubocop: disable Lint/HandleExceptions
      begin
        perform_request
      rescue RuntimeError
        # Ignore the expected error
      end
      # rubocop: enable Lint/HandleExceptions

      expect(GraphqlSchema.persisted_query_error_handler.last_handled_error).to be_a(RuntimeError)
    end
  end
end
