angular.module('admin.orderCycles').controller 'AdminAdvancedOrderCyclesCtrl', ($rootScope, $scope, $location, $timeout, $http, OrderCycles, StatusMessage) ->
  current_order_cycle_id = $location.absUrl().match(/\/admin\/order_cycles\/(\d+)/)[1]
  $scope.order_cycles = OrderCycles.index(ams_prefix: "basic")
  $scope.StatusMessage = StatusMessage

  $scope.copyProducts = ->
    StatusMessage.display 'progress', t('admin.order_cycles.edit.copying_products_and_fees')
    if angular.isDefined($scope.order_cycle_to_copy)
      $http
        method: "POST"
        url: "/admin/order_cycles/" + current_order_cycle_id + "/copy_settings"
        data: { oc_to_copy: $scope.order_cycle_to_copy.id }
      .success (response) ->
        $rootScope.$emit('refreshOC', response.id)
        StatusMessage.display 'progress', t('admin.order_cycles.edit.products_and_fees_copied_refreshing')
      .error (data, status) ->
        StatusMessage.display 'failure', t('admin.order_cycles.edit.failed_to_copy_products_and_fees') + ': ' + status
    else
      StatusMessage.display 'alert', t('admin.order_cycles.edit.select_an_order_cycle_first')
