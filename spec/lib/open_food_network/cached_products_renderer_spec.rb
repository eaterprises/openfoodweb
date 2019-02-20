require 'spec_helper'
require 'open_food_network/cached_products_renderer'

module OpenFoodNetwork
  describe CachedProductsRenderer do
    let(:distributor) { double(:distributor, id: 123) }
    let(:order_cycle) { double(:order_cycle, id: 456) }
    let(:cpr) { CachedProductsRenderer.new(distributor, order_cycle) }

    # keeps global state unchanged
    around do |example|
      original_config = Spree::Config[:enable_products_cache?]
      example.run
      Spree::Config[:enable_products_cache?] = original_config
    end

    describe "#products_json" do
      let(:products_renderer) do
        double(ProductsRenderer, products_json: 'uncached products')
      end

      before do
        allow(ProductsRenderer)
          .to receive(:new)
          .with(distributor, order_cycle) { products_renderer }
      end

      context "products cache toggle" do
        before do
          allow(Rails.env).to receive(:production?) { true }
          Rails.cache.write "products-json-#{distributor.id}-#{order_cycle.id}", 'products'
        end

        context "disabled" do
          before do
            Spree::Config[:enable_products_cache?] = false
          end

          it "returns uncached products JSON" do
            expect(cpr.products_json).to eq 'uncached products'
          end
        end

        context "enabled" do
          before do
            Spree::Config[:enable_products_cache?] = true
          end

          it "returns the cached JSON" do
              expect(cpr.products_json).to eq 'products'
          end
        end
      end

      context "when in testing / development" do
        before do
          allow(Rails.env).to receive(:production?) { false }
        end

        it "returns uncached products JSON" do
          expect(cpr.products_json).to eq 'uncached products'
        end
      end

      context "when in production / staging" do
        before do
          allow(Rails.env).to receive(:production?) { true }
        end

        describe "when the distribution is not set" do
          let(:cpr) { CachedProductsRenderer.new(nil, nil) }

          it "raises an exception and returns no products" do
            expect { cpr.products_json }.to raise_error CachedProductsRenderer::NoProducts
          end
        end

        describe "when the products JSON is already cached" do
          before do
            Rails.cache.write "products-json-#{distributor.id}-#{order_cycle.id}", 'products'
          end

          it "returns the cached JSON" do
            expect(cpr.products_json).to eq 'products'
          end

          it "raises an exception when there are no products" do
            Rails.cache.write "products-json-#{distributor.id}-#{order_cycle.id}", nil
            expect { cpr.products_json }.to raise_error CachedProductsRenderer::NoProducts
          end
        end

        describe "when the products JSON is not cached" do
          let(:cache_key) { "products-json-#{distributor.id}-#{order_cycle.id}" }
          let(:cached_json) { Rails.cache.read(cache_key) }
          let(:cache_present) { Rails.cache.exist?(cache_key) }
          let(:products_renderer) do
            double(ProductsRenderer, products_json: 'fresh products')
          end

          before do
            Rails.cache.delete(cache_key)

            allow(ProductsRenderer)
              .to receive(:new)
              .with(distributor, order_cycle) { products_renderer }
          end

          describe "when there are products" do
            it "returns products as JSON" do
              expect(cpr.products_json).to eq 'fresh products'
            end

            it "caches the JSON" do
              cpr.products_json
              expect(cached_json).to eq 'fresh products'
            end
          end

          describe "when there are no products" do
            let(:products_renderer) { double(ProductsRenderer) }

            before do
              allow(products_renderer).to receive(:products_json).and_raise ProductsRenderer::NoProducts

              allow(ProductsRenderer)
                .to receive(:new)
                .with(distributor, order_cycle) { products_renderer }
            end

            it "raises an error" do
              expect { cpr.products_json }.to raise_error CachedProductsRenderer::NoProducts
            end

            it "caches the products as nil" do
              expect { cpr.products_json }.to raise_error CachedProductsRenderer::NoProducts
              expect(cache_present).to be
              expect(cached_json).to be_nil
            end
          end
        end
      end
    end
  end
end
