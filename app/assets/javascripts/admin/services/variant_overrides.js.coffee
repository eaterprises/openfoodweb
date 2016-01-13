angular.module("ofn.admin").factory "VariantOverrides", (variantOverrides, Indexer, $http) ->
  new class VariantOverrides
    variantOverrides: {}

    constructor: ->
      for vo in variantOverrides
        @variantOverrides[vo.hub_id] ||= {}
        @variantOverrides[vo.hub_id][vo.variant_id] = vo

    ensureDataFor: (hubs, products) ->
      for hub in hubs
        @variantOverrides[hub.id] ||= {}
        for product in products
          for variant in product.variants
            @variantOverrides[hub.id][variant.id] ||=
              variant_id: variant.id
              hub_id: hub.id
              price: ''
              count_on_hand: ''
              default_stock: ''
              resettable: false

    updateIds: (updatedVos) ->
      for vo in updatedVos
        @variantOverrides[vo.hub_id][vo.variant_id].id = vo.id

    resetStock: ->
      $http
        method: "POST"
        url: "/admin/variant_overrides/bulk_reset"
        data:
          variant_overrides: variantOverrides

    updateData: (updatedVos) ->
      for vo in updatedVos
        @variantOverrides[vo.hub_id][vo.variant_id] = vo
