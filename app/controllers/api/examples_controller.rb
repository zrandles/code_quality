module Api
  class ExamplesController < ApplicationController
    # Skip CSRF for API requests (we use Bearer token auth instead)
    skip_before_action :verify_authenticity_token

    before_action :authenticate_api_token

    # GET /api/examples
    # Returns all examples as JSON
    #
    # Query params:
    #   status: Filter by status (new, in_progress, completed, archived)
    #   category: Filter by category (ui_pattern, backend_pattern, etc.)
    #   limit: Limit number of results
    #
    # Example:
    #   curl -H "Authorization: Bearer YOUR_TOKEN" https://24.199.71.69/golden_deployment/api/examples
    def index
      examples = Example.all

      # Apply filters
      examples = examples.where(status: params[:status]) if params[:status].present?
      examples = examples.where(category: params[:category]) if params[:category].present?
      examples = examples.limit(params[:limit].to_i) if params[:limit].present?

      render json: {
        success: true,
        count: examples.count,
        examples: examples.map { |example| example_to_json(example) }
      }
    end

    # POST /api/examples/bulk_upsert
    # Creates or updates multiple examples in a single transaction
    #
    # Expected format:
    # {
    #   "examples": [
    #     {
    #       "name": "Example Name",            # Unique identifier for upsert
    #       "category": "ui_pattern",
    #       "status": "completed",
    #       "description": "...",
    #       "priority": 5,
    #       "score": 85,
    #       "complexity": 3,
    #       "speed": 4,
    #       "quality": 5
    #     }
    #   ]
    # }
    #
    # Returns:
    #   { success: true, created_count: X, updated_count: Y, created: [...], updated: [...] }
    #
    # Example:
    #   curl -X POST \
    #     -H "Authorization: Bearer YOUR_TOKEN" \
    #     -H "Content-Type: application/json" \
    #     -d '{"examples": [{"name": "Test", "status": "new", "category": "ui_pattern"}]}' \
    #     https://24.199.71.69/golden_deployment/api/examples/bulk_upsert
    def bulk_upsert
      examples_data = params.require(:examples)

      created_examples = []
      updated_examples = []
      errors = []

      # Use transaction for all-or-nothing operation
      ActiveRecord::Base.transaction do
        examples_data.each_with_index do |example_data, index|
          begin
            # Find existing example by name (unique identifier)
            example = Example.find_by(name: example_data[:name])

            if example
              # Update existing example
              if example.update(example_params(example_data))
                updated_examples << example
              else
                add_validation_error(errors, index, example_data[:name], example)
                raise ActiveRecord::Rollback
              end
            else
              # Create new example
              example = Example.new(example_params(example_data))
              if example.save
                created_examples << example
              else
                add_validation_error(errors, index, example_data[:name], example)
                raise ActiveRecord::Rollback
              end
            end
          rescue StandardError => error
            errors << { index: index, name: example_data[:name], error: error.message }
            raise ActiveRecord::Rollback
          end
        end
      end

      if errors.empty?
        render json: {
          success: true,
          created_count: created_examples.size,
          updated_count: updated_examples.size,
          created: created_examples.map { |e| { id: e.id, name: e.name } },
          updated: updated_examples.map { |e| { id: e.id, name: e.name } }
        }, status: :created
      else
        render json: {
          success: false,
          errors: errors
        }, status: :unprocessable_entity
      end
    end

    private

    # Authenticate API requests with Bearer token
    # Token is stored in Rails credentials or ENV variable
    #
    # Setup:
    #   1. Generate token: SecureRandom.hex(32)
    #   2. Store in credentials: rails credentials:edit
    #      api:
    #        golden_deployment_token: "your-token-here"
    #   3. OR set ENV var: GOLDEN_DEPLOYMENT_API_TOKEN="your-token-here"
    def authenticate_api_token
      token = request.headers['Authorization']&.sub('Bearer ', '')

      # Get expected token from credentials or environment
      expected_token = Rails.application.credentials.dig(:api, :golden_deployment_token) ||
                      ENV['GOLDEN_DEPLOYMENT_API_TOKEN']

      unless expected_token.present?
        render json: { error: 'API not configured' }, status: :internal_server_error
        return
      end

      # Use secure comparison to prevent timing attacks
      unless ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected_token.to_s)
        render json: { error: 'Unauthorized - Invalid or missing API token' }, status: :unauthorized
      end
    end

    # Helper to add validation error to errors array
    def add_validation_error(errors, index, name, example)
      errors << { index: index, name: name, errors: example.errors.full_messages }
    end

    # Strong parameters for example attributes
    # Only allows explicitly permitted fields
    def example_params(data)
      {
        name: data['name'] || data[:name],
        category: data['category'] || data[:category],
        status: data['status'] || data[:status],
        description: data['description'] || data[:description],
        priority: data['priority'] || data[:priority],
        score: data['score'] || data[:score],
        complexity: data['complexity'] || data[:complexity],
        speed: data['speed'] || data[:speed],
        quality: data['quality'] || data[:quality]
      }.compact
    end

    # Convert example to JSON representation
    def example_to_json(example)
      {
        id: example.id,
        name: example.name,
        category: example.category,
        status: example.status,
        description: example.description,
        priority: example.priority,
        score: example.score,
        complexity: example.complexity,
        speed: example.speed,
        quality: example.quality,
        average_metrics: example.average_metrics,
        created_at: example.created_at,
        updated_at: example.updated_at
      }
    end
  end
end
