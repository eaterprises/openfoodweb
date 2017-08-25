Darkswarm.controller "CreditCardsCtrl", ($scope, $timeout, CreditCard, CreditCards, StripeJS, Dates) ->
  angular.extend(this, new FieldsetMixin($scope))
  $scope.savedCreditCards = CreditCards.saved
  $scope.CreditCard = CreditCard
  $scope.secrets = CreditCard.secrets
  $scope.showForm = CreditCard.show
  $scope.storeCard = CreditCard.requestToken

  $scope.allow_name_change = true
  $scope.disable_fields = false
  $scope.months = Dates.months
  $scope.years = Dates.years
