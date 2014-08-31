describe "Hubs service", ->
  Hubs = null
  Enterprises = null
  CurrentHubMock = {} 
  hubs = [
    {
      id: 2
      active: false
      orders_close_at: new Date()
      is_distributor: true
    }
    {
      id: 3
      active: false
      orders_close_at: new Date()
      is_distributor: true
    }
    {
      id: 1
      active: true
      orders_close_at: new Date()
      is_distributor: true
    }
  ]

  
  beforeEach ->
    module 'Darkswarm'
    angular.module('Darkswarm').value('enterprises', hubs) 
    module ($provide)->
      $provide.value "CurrentHub", CurrentHubMock 
      null
    inject ($injector)->
      Enterprises = $injector.get("Enterprises") 
      Hubs = $injector.get("Hubs")

  it "filters Enterprise.hubs into a new array", ->
    expect(Hubs.hubs[0]).toBe Enterprises.enterprises[2]
    # Because the $filter is a new sorted array 
    # We check to see the objects in both arrays are still the same
    Enterprises.enterprises[2].active = false 
    expect(Hubs.hubs[0].active).toBe false

