describe "SplitCheckoutCtrl", ->
  ctrl = null
  scope = null
  Checkout = null
  CurrentUser = null
  CurrentHubMock =
    hub:
      id: 1
  ShippingMethods = null
  shippingMethods = [
    {id: 1, price: "1.2"}
  ]
  availableCountries = [
    {id: 109, name: "Australia", states: [{id: 55, name: "ACT", abbr: "ACT"}]}
  ]
  
  beforeEach ->
    module("Darkswarm")
    angular.module('Darkswarm').value('user', {})
    angular.module('Darkswarm').value('currentHub', {id: 1})
    angular.module('Darkswarm').value('shippingMethods', shippingMethods)
    module ($provide)->
      $provide.value "CurrentHub", CurrentHubMock
      null
    Checkout =
      purchase: ->
      submit: ->
      navigate: ->
      order:
        id: 1
        email: "public"
        user_id: 1
        bill_address: 'bill_address'
        ship_address: 'ship address'
      secrets:
        card_number: "this is a secret"

  describe "with user", ->
    beforeEach ->
      inject ($controller, $rootScope) ->
        scope = $rootScope.$new()
        CurrentUser = { id: 1 }
        ctrl = $controller 'SplitCheckoutCtrl', {$scope: scope, Checkout: Checkout, CurrentUser: CurrentUser, availableCountries: availableCountries }
      
    describe "submitting", ->
      event =
        preventDefault: ->

      beforeEach ->
        spyOn(Checkout, "purchase")
        scope.submitted = false

      it "delegates to the service when valid", ->
        scope.purchase(event, {$valid: true})
        expect(Checkout.purchase).toHaveBeenCalled()
        expect(scope.submitted).toBe(true)

      it "does nothing when invalid", ->
        scope.purchase(event, {$valid: false})
        expect(Checkout.purchase).not.toHaveBeenCalled()
        expect(scope.submitted).toBe(true)

    it "is enabled", ->
      expect(scope.enabled).toEqual true

  describe "without user", ->
    beforeEach ->
      inject ($controller, $rootScope) ->
        scope = $rootScope.$new()
        ctrl = $controller 'SplitCheckoutCtrl', {$scope: scope, Checkout: Checkout, CurrentUser: {}, availableCountries: availableCountries}

    it "is disabled", ->
      expect(scope.enabled).toEqual false

