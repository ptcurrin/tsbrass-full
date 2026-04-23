import { LightningElement, wire, track, api } from 'lwc'
import methodSetUpAndCheckPermissions from '@salesforce/apex/CustomListviewDisplayController.setUpAndCheckPermissions'
import methodRetrieveListViews from '@salesforce/apex/CustomListviewDisplayController.retrieveListViews'
import methodRetrieveSObjectsByListView from '@salesforce/apex/CustomListviewDisplayController.retrieveSObjectsByListView'
import methodRetrieveOrgBaseURL from '@salesforce/apex/CustomListviewDisplayController.retrieveOrgBaseURL'

const columns = [
  { label: 'End Date: ', fieldName: 'EndDate', type: 'date' },
  {
    label: 'Subject',
    fieldName: 'orgUrlPlusId',
    type: 'url',
    typeAttributes: { label: { fieldName: 'Subject' }, target: 'orgUrlPlusId' }
  },
  { label: 'Name: ', fieldName: 'WhoName', type: 'text' },
  { label: 'Related To: ', fieldName: 'WhatName', type: 'text' },
  { label: 'Assigned Alias: ', fieldName: 'OwnerAlias', type: 'Text' },
  { label: 'All-day: ', fieldName: 'IsAllDayEvent', type: 'boolean' }
]

export default class EventsTeamDisplay extends LightningElement {
  @api defaultChoice

  @track hasPermission

  @track columns = columns

  @track _events
  get events () {
    return this._events
  }
  set events (value) {
    this._events = value
  }

  @track errorEventsGet
  @track isLoaded = false
  @track isKanban
  @track isTable
  @api valueDisplayType = 'utility:kanban'

  @track
  optionsDisplayType = [
    { label: 'Kanban', value: 'utility:kanban' },
    { label: 'Table', value: 'utility:table' }
  ]

  handleChangeDisplayType (event) {
    console.log(
      'method ENTER handleChangeDisplayType: ' + JSON.stringify(event, null, 2)
    )

    this.valueDisplayType = event.detail.value

    console.log('this.valueDisplayType : ' + this.valueDisplayType)

    if (this.valueDisplayType == 'utility:kanban') {
      this.isKanban = true
      this.isTable = false
    } else if (this.valueDisplayType == 'utility:table') {
      this.isTable = true
      this.isKanban = false
    }

    console.log('isKanban: ' + this.isKanban)
    console.log('isTable: ' + this.isTable)
  }

  hasCalledForListViewsOnce = false

  async setUpAndCheckPermissions(){
    
		await methodSetUpAndCheckPermissions()
		.then(result => {
			this.hasPermission = result;
			this.error = undefined;
      return
		})
		.catch(error => {
			this.error = error;
			this.hasPermission = false
      return
		})
  }

  @wire(methodRetrieveListViews, { sObjectType: 'Event' })
  listviewList ({ error, data }) {
    if (data) {
      console.log('data: ' + JSON.stringify(data, null, 2))
      let listViewsTemp = []

      data.forEach(element => {
        listViewsTemp.push({
          label: element.Name,
          value: element.Id,
          DeveloperName: element.DeveloperName
        })
      })

      this.listViewsDisplayed = listViewsTemp

      //{
      //  "Id": "00B5500000ANOwTEAX",
      //  "Name": "My Team's Past Open Internal Meetings",
      //  "DeveloperName": "MyPastOpenMeetings",
      //  "SobjectType": "Event"
      //},

      if (this.defaultChoice && this.hasCalledForListViewsOnce == false) {
        console.log('%%% this.defaultChoice: ' + this.defaultChoice)
        console.log(
          '%%% this.hasCalledForListViewsOnce: ' +
            this.hasCalledForListViewsOnce
        )

        this.listViewsDisplayed.forEach(x => {
          console.log('%% ' + JSON.stringify(x))

          if (x['label'] == this.defaultChoice) {
            console.log('%% yes...  ' + x['label'])
            //this.listViewId = x['value']

            let evt = {}
            let detail = {}
            detail['value'] = x['value']
            evt['detail'] = detail

            this.handleChangeListViewId(evt)
          } else {
            console.log('%% no ...  ' + x['label'])
          }
        })

        this.hasCalledForListViewsOnce = true
      }
    } else if (error) {
      this.error = error
      console.log('error: ' + JSON.stringify(this.error, null, 2))
    }

    this.isLoaded = true
  }

  _listViewsDisplayStore
  get listViewsDisplayed () {
    return this._listViewsDisplayStore
  }
  set listViewsDisplayed (value) {
    this.setAttribute('listViewsDisplayed', value)
    this._listViewsDisplayStore = value
  }

  constructor () {
    super()
    console.log('EventsTeamDisplay Constructor ENTER')

    this.isLoaded = false
  }

  orgBaseUrl = ''

  async connectedCallback () {
    console.log('EventsTeamDisplay connectedCallback ENTER')

    await methodRetrieveOrgBaseURL()
      .then(result => {
        this.orgBaseUrl = result

        console.log('orgBaseUrl: ' + this.orgBaseUrl)
      })
      .catch(error => {
        this.errorEventsGet = error
      })

     await this.setUpAndCheckPermissions()
  
      console.log('hasPermission: ' + this.hasPermission)

  }

  renderedCallback () {
    console.log('EventsTeamDisplay renderedCallback ENTER')

    this.isLoaded = true

    if (this.valueDisplayType == 'utility:kanban') {
      this.isKanban = true
      this.isTable = false
    } else if (this.valueDisplayType == 'utility:table') {
      this.isTable = true
      this.isKanban = false
    }
  }

  disconnectedCallback () {
    console.log('EventsTeamDisplay disconnectedCallback ENTER')
  }

  errorCallback () {
    console.log('EventsTeamDisplay errorCallback ENTER')
  }

  listViewId = ''
  @track
  listViewName = ''
  listViewDeveloperName = ''
  listViewAddress = ''
  events = []
  numFoundEvents = 0

  get options () {
    return this.listViewsDisplayed

    //return [
    //  { label: 'New', value: 'new' },
    //  { label: 'In Progress', value: 'inProgress' },
    //  { label: 'Finished', value: 'finished' }
    //]
  }

  handleChangeListViewId (event) {
    console.log('%%% method handleChangeListView')

    this.isLoaded = false

    this.listViewId = event.detail.value

    console.log('$$$ ' + JSON.stringify(event.detail, null, 2))

    this.listViewsDisplayed.forEach(element => {
      console.log('comparison: ' + JSON.stringify(element))

      if (element.value === event.detail.value) {
        console.log('%%% FOUND:  ' + element.label)

        this.listViewName = element.label
        this.listViewDeveloperName = element.DeveloperName
      }
    })

    if (this.listViewId) {
      // "https://tsbrass--uat.sandbox.lightning.force.com/lightning/o/Event/list?filterName=MyRecentEvents"

      console.log('%%% addres2: ' + this.listViewDeveloperName)
      this.listViewAddress =
        this.orgBaseUrl +
        '/lightning/o/Event/list?filterName=' +
        this.listViewDeveloperName
      console.log('%%% listViewAddress: ' + this.listViewAddress)

      methodRetrieveSObjectsByListView({
        filterId: this.listViewId,
        sObjectType: 'Event'
      })
        .then(result => {
          let shownEvents = []

          let countUpTo3 = 0
          let count = 0
          result.forEach(element => {
            console.log('%%% element: ' + JSON.stringify(element, null, 2))

            let x = Object.create(element)

            // These are compound fields that need to be displayed in a datatable sometimes... gotta get rid of the period chars
            if (x['Who']) {
              x['WhoName'] = x['Who']['Name']
            }

            if (x['What']) {
              x['WhatName'] = x['What']['Name']
            }

            if (x['Owner']) {
              x['OwnerAlias'] = x['Owner']['Alias']
            }

            // This is where the link is manufactured
            x.orgUrlPlusId = this.orgBaseUrl + '/' + element.Id

            console.log('element.orgUrlPlusId: ' + x.orgUrlPlusId)

            if (countUpTo3 < 3) {
              shownEvents.push(x)
              countUpTo3 = countUpTo3 + 1
            } else {
              console.log('somehow count3 is not less than 3...')
            }
            count = count + 1
          })
          this.events = shownEvents

          if (count < 4) {
            this.numFoundEvents = count + ''
          } else {
            this.numFoundEvents = '3+'
          }
        })
        .catch(error => {
          this.errorEventsGet = error
        })

      this.isLoaded = true
    } else {
      this.isLoaded = true
    }
  }
}