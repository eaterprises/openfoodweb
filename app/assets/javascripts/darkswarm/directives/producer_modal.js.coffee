Darkswarm.directive "producerModal", ($modal)->
  restrict: 'E'
  replace: true
  template: "<a ng-transclude></a>"
  transclude: true
  link: (scope, elem, attrs, ctrl)->
    elem.on "click", =>
      scope.modalInstance = $modal.open(controller: ctrl, templateUrl: 'producer_modal.html', scope: scope)

