require 'open_food_network/products_renderer'

# Wrapper for ProductsRenderer that caches the JSON output.
# ProductsRenderer::NoProducts is represented in the cache as nil,
# but re-raised to provide the same interface as ProductsRenderer.

module OpenFoodNetwork
  class CachedProductsRenderer
    class NoProducts < Exception; end

    def initialize(distributor, order_cycle)
      @distributor = distributor
      @order_cycle = order_cycle
    end

    def products_json
      raise NoProducts.new(I18n.t(:no_products)) if @distributor.nil? || @order_cycle.nil?

      products_json = cached_products_json

      raise NoProducts.new(I18n.t(:no_products)) if products_json.nil?

      products_json
    end


    private

    def cached_products_json
      return uncached_products_json unless Spree::Config[:enable_products_cache?]

      if Rails.env.production? || Rails.env.staging?
        Rails.cache.fetch("products-json-#{@distributor.id}-#{@order_cycle.id}") do
          begin
            uncached_products_json
          rescue ProductsRenderer::NoProducts
            nil
          end
        end
      else
        uncached_products_json
      end
    end

    def uncached_products_json
      ProductsRenderer.new(@distributor, @order_cycle).products_json
    end
  end
end
