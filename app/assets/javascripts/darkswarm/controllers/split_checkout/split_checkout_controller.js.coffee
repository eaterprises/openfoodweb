Darkswarm.controller "SplitCheckoutCtrl", ($scope, Checkout, CurrentUser, CurrentHub, AuthenticationService, SpreeUser, $http, ShippingMethods, availableCountries) ->
  $scope.Checkout = Checkout
  $scope.ShippingMethods = ShippingMethods
  $scope.name = "split_checkout"
  $scope.enabled = !!CurrentUser.id?
  
  $scope.countries = availableCountries

  $scope.countriesById = $scope.countries.reduce (obj, country) ->
    obj[country.id] = country
    obj
  , {}

  $scope.purchase = (event, form) ->
    event.preventDefault()
    $scope.formdata = form
    $scope.submitted = true

    if CurrentUser.id
      $scope.validateForm(form)
    else
      $scope.ensureUserIsGuest()

  $scope.validateForm = ->
    if $scope.formdata.$valid
      $scope.Checkout.purchase()
    else
      $scope.$broadcast 'purchaseFormInvalid', $scope.formdata

  $scope.ensureUserIsGuest = (callback = null) ->
    $http.post("/user/registered_email", {email: $scope.order.email}).success (data)->
      if data.registered == true
        $scope.promptLogin()
      else
        $scope.validateForm() if $scope.submitted
        callback() if callback

  $scope.promptLogin = ->
    SpreeUser.spree_user.email = $scope.order.email
    AuthenticationService.pushMessage t('devise.failure.already_registered')
    AuthenticationService.open '/login'

  $scope.form = ->
    $scope[$scope.name]

  $scope.field = (path)->
    $scope.form()[path]

  $scope.fieldValid = (path)->
    not ($scope.dirty(path) and $scope.invalid(path))

  $scope.dirty = (name)->
    $scope.field(name).$dirty || $scope.submitted

  $scope.invalid = (name)->
    $scope.field(name).$invalid

  $scope.error = (name)->
    $scope.field(name).$error

  $scope.fieldErrors = (path)->
    errors = for error, invalid of $scope.error(path)
      if invalid
        switch error
          when "required" then t('split_checkout.errors.required', input_name: path)
          when "number"   then t('split_checkout.errors.invalid_number')
          when "email"    then t('split_checkout.errors.invalid_email')
    #server_errors = $scope.Order.errors[path.replace('order.', '')]
    #errors.push server_errors if server_errors?
    (errors.filter (error) -> error?).join ", "
