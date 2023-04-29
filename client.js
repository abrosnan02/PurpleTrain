const virtualKeyboardSupported = "virtualKeyboard" in navigator;

console.log(virtualKeyboardSupported)

if (virtualKeyboardSupported) {
  //navigator.virtualKeyboard.overlaysContent = true;
}

window.onload = function () {
  bottomBox = document.getElementById("bottomBox")
  toFromBox = document.getElementById("toFromBox")
  calendarBox = document.getElementById("calendarBox")
  fromButton = document.getElementById("fromButton")
  toButton = document.getElementById("toButton")
  schedules = document.getElementById("schedules")
  switchDirButton = document.getElementById("switchDirButton")
  includeDeparted = document.getElementById("includeDeparted")
  includeDepartedContainer = document.getElementById("includeDepartedContainer")
  tripInformation = document.getElementById("tripInformation")
  trainInformation = document.getElementById("trainInformation")
  tripInfoScrollBox = document.getElementById("tripInfoScrollBox")

  calendarDate = new Date()

  currentDay = 0
  stops = []

  fromStation = ''
  toStation = ''
  preview = ''
  
  fetch('/stops', {
      method: 'GET',
      mode: 'cors',
  }).then(async response => {
      if (!response.ok) {
          throw new Error("HTTP error " + response.status);
      }
      stops = await response.json()
  });

  

  function respond() {
    if (bottomBox.getBoundingClientRect().width >= 500) {
      
      bottomBox.style.borderTopLeftRadius = '20px'
      bottomBox.style.borderTopRightRadius = '20px'
      bottomBox.style.left = 'calc(50% - 250px)'
      tripInformation.style.left = 'calc(50% - 250px)'
      bottomBox.style.boxShadow = '0px 0px 40px 0px rgba(0,0,0,0.4)'
      schedules.style.left = 'calc(50% - 250px)'
      tripInformation.style.left = 'calc(50% - 250px)'
    } else {
      schedules.style.width = '100%'
      schedules.style.left = '0'
      tripInformation.style.width = '100%'
      tripInformation.style.left = '0'
      bottomBox.style.borderRadius = '0'
      bottomBox.style.boxShadow = '0px 40px 40px 40px rgba(0,0,0,0.4)'
      bottomBox.style.left = '0'
    }
  }
  respond()
  window.addEventListener("resize", respond)

  /*schedules.onscroll = function(ev) {
    if ((schedules.scrollTop + schedules.offsetHeight) >= schedules.scrollHeight - 1000) {
      getTrainTime(1)
    }
  };*/ 
  const urlVars = new URLSearchParams(window.location.search);
  var from = urlVars.get('from')
  var to = urlVars.get('to')
  var date = urlVars.get('date')
  if (from && to) {
    fromStation = from
    toStation = to
    if (date) {
      var dateTime = date.split("-");
      if (dateTime.length == 3) {
        calendarDate = (new Date(dateTime[0], dateTime[1] - 1, dateTime[2]))
      }
    }
    
    updateButtons()
  }
}

Date.prototype.yyyymmdd = function() { //stackoverflow
  var mm = this.getMonth() + 1; // getMonth() is zero-based
  var dd = this.getDate();

  return [this.getFullYear(),
          (mm>9 ? '' : '0') + mm,
          (dd>9 ? '' : '0') + dd
         ].join('-');
};

function message(type, title, message) {
  var info = document.createElement('div')
  info.classList.add(type)

  var img = document.createElement('img')
  img.src = '/images/' + type + '.svg'

  var line = document.createElement('p')
  line.classList.add("line")
  line.textContent = title

  var text = document.createElement('p')
  text.classList.add("text")
  text.textContent = message

  info.appendChild(img)
  info.appendChild(line)
  info.appendChild(text)
  schedules.appendChild(info)
}

var searching = false
function disableButtons(opacity) {
  searching = true

  toFromBox.style.opacity = opacity
  if (opacity == 0) {
    toFromBox.style.visibility = 'hidden'
  }

  switchDirButton.style.cursor = 'default'
  calendarButton.style.cursor = 'default'
  toButton.style.cursor = 'default'
  fromButton.style.cursor = 'default'
}

function enableButtons() {
  searching = false

  toFromBox.style.visibility = 'initial'
  toFromBox.style.opacity = 1
  
  switchDirButton.style.cursor = 'pointer'
  calendarButton.style.cursor = 'pointer'
  toButton.style.cursor = 'pointer'
  fromButton.style.cursor = 'pointer'
}

var calendarDates = []

function updateCalendar(day, reset) {
  if (reset) {
    calendarDate = new Date()
  } else {
    calendarDate.setDate(calendarDate.getDate() + (day || 0))
  }
  var dayText = document.getElementById('calendarTitle')

  if (isTomorrow(calendarDate, 0)) {
    dayText.textContent = 'Today, ' + calendarDate.toLocaleString('default', {month: 'long'}) + ' ' + calendarDate.getDate()
    includeDepartedContainer.style.visibility = 'initial'
  } else if (isTomorrow(calendarDate, 1)) {
    dayText.textContent = 'Tomorrow, ' + calendarDate.toLocaleString('default', {month: 'long'}) + ' ' + calendarDate.getDate()
    includeDepartedContainer.style.visibility = 'hidden'
    includeDeparted.checked = false
  } else if (isTomorrow(calendarDate, -1)) {
    dayText.textContent = 'Yesterday, ' + calendarDate.toLocaleString('default', {month: 'long'}) + ' ' + calendarDate.getDate()
    includeDepartedContainer.style.visibility = 'hidden'
    includeDeparted.checked = false
  } else {
    dayText.textContent =  calendarDate.toLocaleString('default', {month: 'long'}) + ' ' + calendarDate.getDate()
    includeDepartedContainer.style.visibility = 'hidden'
    includeDeparted.checked = false
  }

  if (day) {
    generateCalendar(calendarDate)
  }
}

function generateCalendar(timeStamp, close) {
  if (close && (timeStamp.getDate() == calendarDate.getDate()) && (timeStamp.getMonth() == calendarDate.getMonth())) {closeCalendar(); updateButtons(); return}
  let dateTime = (new Date(timeStamp))
  let month = dateTime.getMonth()

  let date = dateTime.getDate() //current day #
  
  dateTime.setDate(1) //set day to first of month
  
  let weekDay = dateTime.getDay() //get weekday of first day

  dateTime.setDate((-weekDay + 1)) //set to -weekDay to get date for first table entry
  let firstDay = dateTime.getDate()

  dateTime.setMonth(month + 1)
  dateTime.setDate(0)
  let lastDay = dateTime.getDate()
  

  let calendar = document.getElementById('calendarTable')
  calendar.textContent = ''

  let calendarIndex = 0
  let calendarDay = firstDay
  let calendarMonth = -1

  calendarDates = []
  for (let currentWeek = 0; currentWeek < 6; currentWeek++) {
    let row = document.createElement('tr')

    for (let currentWeekDay = 0; currentWeekDay < 7; currentWeekDay++) {
      let entry = document.createElement('td')
      let a = document.createElement('a')
      
      if (calendarIndex == weekDay) {
        calendarMonth = 0
        calendarDay = 1
      } else if (calendarMonth == 0 && calendarDay > lastDay) {
        calendarMonth = 1
        calendarDay = 1
      }
      
      if (calendarDay == date) {
        entry.id = 'currentDay'
      }
      if (calendarMonth < 0 || calendarMonth > 0) {
        entry.id = 'otherMonth'
      }
      a.textContent = calendarDay

      calendarDates[calendarIndex] = new Date(timeStamp)
      calendarDates[calendarIndex].setMonth(timeStamp.getMonth() + calendarMonth)
      calendarDates[calendarIndex].setDate(calendarDay)

      entry.onclick = (function(dt) {
          return function() {
            calendarDate = dt
            generateCalendar(dt);
          };
      })(calendarDates[calendarIndex]);
      

      entry.appendChild(a)
      row.appendChild(entry)
      calendarIndex++
      calendarDay++
    }
    
    calendar.appendChild(row)
  }
  updateCalendar()
}

function calendar() {
  if (searching) {return}
  disableButtons(0)
  bottomBox.style.height = '100%'

  calendarBox.style.opacity = 1
  calendarBox.style.visibility = 'initial'

  generateCalendar(calendarDate)
}

function isTomorrow(date, days) {
  date.setHours(0, 0, 0, 0)

  const tomorrow = new Date(new Date().setHours(0, 0, 0, 0))
  tomorrow.setDate(tomorrow.getDate() + days);

  return date.toDateString() === tomorrow.toDateString();
}

function closeCalendar() {
  enableButtons()
  bottomBox.style.height = 'calc(var(--toFromBoxHeight))'

  calendarBox.style.transitionDelay = '0s'
  calendarBox.style.opacity = 0
  calendarBox.style.visibility = 'hidden'
}

function getTripInfo(carrier, id, to, from) {
  var tripInfoScrollBox = document.getElementById("tripInfoScrollBox")
  tripInfoScrollBox.textContent = ''

  tripInformation.style.visibility = 'initial'

  var loader = document.createElement('div')
  loader.classList.add("loader")
  loader.style.top = 'calc(50% - var(--px25))'
  tripInfoScrollBox.appendChild(loader)
  
  
  fetch('/getTripInfo', {
    method: 'POST',
    mode: 'cors',
    body: JSON.stringify({"carrier": carrier, "id": id, "to": to, 'from': from}),
  }).then(async response => {
    if (!response.ok) {
        console.log('error')
    }

    tripInfo = await response.json()

    if (tripInfo) {
      tripInfoScrollBox.textContent = ''

      var tripPath = document.createElement('div')
      tripPath.classList.add('tripPath')

      var filler = document.createElement('div')
      filler.style.width = 'auto'
      filler.style.height = 'var(--px35)'
      tripInfoScrollBox.appendChild(filler)
      

      

      if (tripInfo.path) {
        var stops = tripInfo.path.length
        for (var i = 0; i < stops; i++) {
          var stop = document.createElement('div')
          stop.classList.add("stop")

          var time = document.createElement('p')
          time.innerHTML = tripInfo.path[i].time.hour + ':' +
            tripInfo.path[i].time.min + '<strong>' +
            tripInfo.path[i].time.ampm + '</strong>'

          var stopName = document.createElement('p')
          stopName.textContent = tripInfo.path[i].name
          stopName.classList.add("stopName")

          var dotBox = document.createElement('div')
          var dot = document.createElement('div')
          var line = document.createElement('div')
          line.classList.add("line")
          dot.classList.add("dot")
          dotBox.appendChild(line)
          dotBox.appendChild(dot)
          
          if (i == 0 || i == stops - 1) {
            time.classList.add("originTime")
            stopName.classList.add("bold")

            if (i == stops - 1) {
              dotBox.classList.add("terminus")
            } else {
              dotBox.classList.add("origin")
            }
          } else {
            dotBox.classList.add("infill")
            time.classList.add("infillTime")
          }

          stop.appendChild(time)
          stop.appendChild(stopName)
          stop.appendChild(dotBox)
          tripPath.appendChild(stop)
        }
        
        var devInfo = document.createElement('div')
        devInfo.classList.add("devInfo")

        var tripId = document.createElement('div')
        tripId.classList.add("tripId")
        tripId.textContent =  ''

        tripInfoScrollBox.appendChild(tripPath)

        if (tripInfo.headsign) {
          var tripHeadsign = document.createElement('div')
          tripHeadsign.classList.add("tripId")
          tripHeadsign.textContent = tripInfo.headsign
          devInfo.appendChild(tripHeadsign)
        }

        if (tripInfo.scheduleId) {
          console.log('Schedule ID: ' + tripInfo.scheduleId)
        }

        devInfo.appendChild(tripId)
        tripInfoScrollBox.appendChild(devInfo)

      } else if (tripInfo.error) {
        var error = document.createElement('p')
        error.textContent = tripInfo.error
        error.classList.add("error")
        tripInfoScrollBox.appendChild(error)
      }
    }
  });
}

function closeTripInfo() {
  tripInformation.style.visibility = 'hidden'
}

function getTrainTime(date, clearSchedules, addFiller) {
  var today = new Date().yyyymmdd();
  
  if (currentDay > 0) {return}
  disableButtons(.25)

  if (today == date) {
    currentDay = 0
  } else {
    currentDay = 1
  }

  var trainTimes
  fetch('/getTrainTime', {
    method: 'POST',
    mode: 'cors',
    body: JSON.stringify({"from": fromStation, "to": toStation, "date": date, "includeDeparted": includeDeparted.checked}),
  }).then(async response => {
      if (!response.ok) {
          throw new Error("HTTP error " + response.status);
      }

      trainTimes = await response.json()

      if (trainTimes) {
        if (clearSchedules) {schedules.textContent = ''}

        //toStation = trainTimes.stations.to
        //fromStation = trainTimes.stations.from
        
        var arrayLength = trainTimes.length
        for (var i = 0; i < arrayLength; i++) {
          if (trainTimes[i].type == 'trip') {
            let carrier = trainTimes[i].carrier
            let id = trainTimes[i].id
            let route = (trainTimes[i].route).toUpperCase()
            let number = trainTimes[i].number
            let prediction = trainTimes[i].prediction
            let direction = trainTimes[i].direction

            var scheduleCard = document.createElement('div')
            scheduleCard.classList.add("schedule")
            scheduleCard.onclick = function() {
              //document.getElementById('tripId').innerHTML = '<strong>Trip ID: </strong>' + id
              document.getElementById('tripTitle').innerHTML = 'Train ' + String(number) + '<strong> ' + carrier + '</strong>'
              document.getElementById('tripRoute').textContent = route
              if (prediction == '') {
                //document.getElementById('tripPrediction').textContent = direction + ' • On time'
              } else {
                //document.getElementById('tripPrediction').textContent = direction + ' • ' + prediction
              }
              console.log('Trip ID: ' + id)
              getTripInfo(carrier, id, toStation, fromStation)
            }

            if (date == today && trainTimes[i].wait == 'Departed') {
              scheduleCard.style.opacity = .5
            }

            var scheduleLine = document.createElement('p')
            scheduleLine.classList.add("scheduleLine")
            scheduleLine.textContent = route
            scheduleLine.classList.add('scheduleLine' + trainTimes[i].carrier)

            var scheduleNumber = document.createElement('p')
            scheduleNumber.classList.add("scheduleNumber")
            scheduleNumber.textContent = number
            scheduleNumber.classList.add('scheduleNumber' + trainTimes[i].carrier)

            var scheduleTime = document.createElement('p')
            scheduleTime.classList.add("scheduleTime")
            scheduleTime.innerHTML = trainTimes[i].predictedTime.hour + ':' +
              trainTimes[i].predictedTime.min + '<strong>' + 
              trainTimes[i].predictedTime.ampm + '</strong> -> ' +
              trainTimes[i].arrivalTime.hour + ':' + 
              trainTimes[i].arrivalTime.min + '<strong>' + 
              trainTimes[i].arrivalTime.ampm +'</strong>' +
              '<b> (' + trainTimes[i].duration + ')</b>'

            
            var scheduleTo = document.createElement('p')
            scheduleTo.classList.add("scheduleTo")
            scheduleTo.textContent = 'To ' + trainTimes[i].to
            
            var scheduleFrom = document.createElement('p')
            scheduleFrom.classList.add("scheduleFrom")
            scheduleFrom.textContent = 'From ' + trainTimes[i].from
            
            var scheduleWait = document.createElement('p')
            scheduleWait.classList.add("scheduleWait")
            scheduleWait.textContent = trainTimes[i].wait

            var scheduleCost = document.createElement('p')
            scheduleCost.classList.add("scheduleCost")
            scheduleCost.textContent = trainTimes[i].fare
            

            var schedulePrediction = document.createElement('p')
            schedulePrediction.classList.add("schedulePrediction")
            schedulePrediction.textContent = prediction
            
            var scheduleDirection = document.createElement('p')
            scheduleDirection.classList.add("scheduleDirection")
            scheduleDirection.textContent = direction


            
            scheduleCard.appendChild(scheduleLine)
            scheduleLine.appendChild(scheduleNumber)
            scheduleCard.appendChild(scheduleTime)
            scheduleCard.appendChild(scheduleTo)
            scheduleCard.appendChild(scheduleFrom)
            scheduleCard.appendChild(schedulePrediction)
            scheduleCard.appendChild(scheduleCost)
            scheduleCard.appendChild(scheduleWait)
            scheduleCard.appendChild(scheduleDirection)
            schedules.appendChild(scheduleCard)
          } else if (trainTimes[i].type == 'title') {
            var title = document.createElement('p')
            title.classList.add("scheduleTitle")
            title.textContent = trainTimes[i].text
            schedules.appendChild(title)
          } else if (trainTimes[i].type == 'info') {
            message('info', trainTimes[i].title, trainTimes[i].text)
          } else if (trainTimes[i].type == 'alert') {
              message('alert', trainTimes[i].title, trainTimes[i].text)
          } else if (trainTimes[i].type == 'stations') {
            fromStation = trainTimes[i].names.from
            toStation = trainTimes[i].names.to
          } else if (trainTimes[i].type == 'filler') {
            var filler = document.createElement('div')
          filler.classList.add("filler")
          filler.id = 'filler'
          filler.textContent = trainTimes[i].text
          schedules.appendChild(filler)
          }
        }
      }
      
      if (fromStation === '') {fromButton.textContent = 'SELECT A STATION'}
      if (toStation === '') {toButton.textContent = 'SELECT A STATION'}
      enableButtons()
  })
  
}

function updateButtons() {
  if (searching) {return}
  if (fromStation == toStation) {
    schedules.textContent = ''

    var title = document.createElement('p')
    title.classList.add("scheduleTitle")
    title.textContent = 'Please enter a different station'
    schedules.appendChild(title)

    return
  }
  
  fromButton.textContent = fromStation.toUpperCase()
  toButton.textContent = toStation.toUpperCase()

  if (fromStation === '') {fromButton.textContent = 'SELECT A STATION'}
  if (toStation === '') {toButton.textContent = 'SELECT A STATION'}

  if ((fromStation.length > 0) && (toStation.length > 0)) {
    currentDay = 0
    schedules.textContent = ''

    var loader = document.createElement('div')
    loader.classList.add("loader")
    schedules.appendChild(loader)
    
    getTrainTime(calendarDate.yyyymmdd(), true, true)
  }
}


function autocomplete(button) {
  if (searching) {return}
  if (stops.length == 0) {return}
  
  var searchBox = document.createElement('div')
  searchBox.classList.add("searchBox")
  if (virtualKeyboardSupported) {
    //searchBox.classList.add("virtualKeyboard")
  }

  var searchInput = document.createElement('textArea')
  searchInput.classList.add("searchInput")
  searchInput.spellcheck= 'false'
  searchInput.autocomplete = 'off'
  searchInput.autocorrect= 'off'
  searchInput.placeholder = "Search for a station or city..."

  var searchInputPreview = document.createElement('p')
  searchInputPreview.classList.add("searchInputPreview")

  if (button < 1) {
    preview = fromStation
    searchInput.value = fromStation
    searchInputPreview.textContent = fromStation
  } else if (button > 0) {
    preview = toStation
    searchInput.value = toStation
    searchInputPreview.textContent = toStation
  }

  var searchResults = document.createElement('div')
  searchResults.classList.add("searchResults")
  
  searchBox.appendChild(searchInput)
  searchBox.appendChild(searchInputPreview)
  searchBox.appendChild(searchResults)
  document.body.appendChild(searchBox)
  searchInput.select()

  searchInput.addEventListener("input", function(event) {
    searchResults.textContent = ''
    this.value = this.value.trimStart().replace(/(\r\n|\n|\r)/gm, "");
    var value = this.value.toLowerCase();
    var currentResult = 0
    var resultAmount = Math.floor((searchBox.clientHeight - 30) / 60) - 1
    var arrayLength = stops.length;
    var valueLength = value.length;

    if (valueLength > 0) {
      preview = undefined
      for (let i = 0; i < arrayLength; i++) {
        if (currentResult >= resultAmount) {
          break
        }
        
        var stop = stops[i]
        if (stop.name.substring(0, valueLength).toLowerCase() === value) {
          currentResult++
          if (currentResult === 1){
            preview = stop.name
            searchInputPreview.innerHTML = preview + ' ' + '<strong>-></strong>'
            searchInput.value = stop.name.substring(0, valueLength)
          }
          let result = document.createElement('a')
          result.onclick = (function(){
            if (button == 0) {
              fromStation = stops[i].name
              updateButtons()
              searchBox.remove()
            } else {
              toStation = stops[i].name
              updateButtons()
              searchBox.remove()
            }
          })
          result.onmouseenter = (function(){
            result.style.backgroundColor = 'rgba(255, 255, 255, .15)'
          })
          result.onmouseleave = (function(){
            result.style.backgroundColor = 'rgba(255, 255, 255, 0)'
          })
          result.classList.add("result")
          result.innerHTML = '<strong>' + 
            stop.name.substring(0, valueLength) + 
            '</strong>' + 
            stop.name.substring(valueLength) +
            ' <strong class="municipality">' + 
            (stop.municipality || '') + '</strong>'
          searchResults.appendChild(result)
        } 
      }
    }
    if (currentResult === 0) {
      searchInputPreview.textContent = ''
    }
  });

  searchInput.onblur = function() {
    if (searchResults.textContent == '') {
      searchBox.remove()
    }
  }

  searchInput.addEventListener("keydown", function(event) {
    const key = event.key; // Or const {key} = event; in ES6+
    if (key === "Escape") {
      searchBox.remove()
    } else if (key === "Enter") {
      if (preview) {
        if (button == 0) {
          fromStation = preview
          updateButtons()
          searchBox.remove()
        } else {
          toStation = preview
          updateButtons()
          searchBox.remove()
        }
      }
    }
  });
}

function get(button) {
  autocomplete(button)
}

function swap() {
  var toStationBak = toStation
  toStation = fromStation
  fromStation = toStationBak

  updateButtons()
}
