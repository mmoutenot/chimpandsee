React = require 'react'
classnames = require 'classnames'
_ = require 'underscore'
ImmutableOptimizations = require('react-cursor').ImmutableOptimizations

Subject = require 'zooniverse/models/subject'
Classification = require 'zooniverse/models/classification'

steps = require '../lib/steps'
chimp = steps[2][0].animal.options[2]
animatedScrollTo = require 'animated-scrollto'

Step = React.createClass
  displayName: 'Step'
  mixins: [ImmutableOptimizations(['step', 'notes'])]

  getInitialState: ->
    values: []

  onButtonClick: ({currentTarget}) ->
    button = currentTarget
    human = steps[2][0].animal.options[9]
    notAChimp = @animalCheck(button.value, chimp)

    switch
      when button.value is steps[0][0].presence.options[0] and @props.step.value is 0
        @storeSelection(button.name, button.value)
        setTimeout (=>
          console?.log 'send to classification', @props.classification
          @props.classification.annotate @props.currentAnswers
          @sendClassification()
          @nextSubject()
        )
      when button.value is steps[0][0].presence.options[1]
        @moveToNextStep()
      when button.value is steps[1][0].annotation.options[0]
        @storeSelection(button.name, button.value)
        setTimeout ( =>
          console?.log 'send to classification', @props.classification
          @props.classification.annotate @props.currentAnswers
          @props.resetVideo()
          @sendClassification()
          @nextSubject()
        )
      when button.value is steps[1][0].annotation.options[1] then @moveToNextStep()
      when button.value is steps[1][0].annotation.options[2] then @finishNote()
      when button.value is chimp
        @storeSelection(button.name, button.value)
        @storeSelection('number', '1')
        @props.step.set 3
        @props.subStep.set 0
      when button.value is human
        @storeSelection(button.name, button.value)
        @storeSelection('number', '1')
        @storeSelection('behavior', ['no behavior'])
        setTimeout (=> @addNote() )
      when button.value is notAChimp[0]
        @storeSelection(button.name, button.value)
        @storeSelection('number', '1')
        @props.step.set 3
        @props.subStep.set 3
      when steps[3][0].age.options.indexOf(button.value) >= 0
        @storeSelection(button.name, button.value)
        @props.step.set 3
        @props.subStep.set 1
      when steps[3][1].sex.options.indexOf(button.value) >= 0
        @storeSelection(button.name, button.value)
        @props.step.set 3
        @props.subStep.set 2
      when button.value is steps[4][0].summary.options[0] then @nextSubject()
      when steps[3][3].number.options.indexOf(button.value) >= 0
        @storeSelection(button.name, button.value)
      else
        @storeMultipleSelections(button.name, button.value)

  animalCheck: (buttonValue, excludeThisAnimal) ->
    notThisAnimal = _.without steps[2][0].animal.options, excludeThisAnimal
    otherAnimal = notThisAnimal.map (animal) ->
      animal if animal is buttonValue
    otherAnimal = _.compact(otherAnimal)
    otherAnimal

  componentWillReceiveProps: (nextProps) ->
    window.scrollTo 0, 0 if window.innerWidth < 601 and nextProps.step.value < 2

  storeMultipleSelections: (name, value) ->
    index = @state.values.indexOf(value)

    if index >= 0
      currentValues = @state.values
      currentValues.splice index, 1
      @setState({values: currentValues}, @storeSelection(name, @state.values))
    else
      currentValues = @state.values
      currentValues.push value
      @setState({values: currentValues}, @storeSelection(name, @state.values))

  clearMultipleSelection: ->
    @setState values: []

  storeSelection: (name, value) ->
    obj = {}
    obj[name] = value
    currentAnswers = @props.currentAnswers
    newAnswers = _.extend currentAnswers, obj
    @props.setCurrentAnswers newAnswers
    @forceUpdate()

  moveToNextStep: ->
    @props.step.set Math.min @props.step.value + 1, steps.length

  goToAnimalStep: (event) ->
    @clearMultipleSelection()
    button = event.target

    @goToStep(button.value, 0)

  goToSubStep: (event) ->
    @clearMultipleSelection()
    button = event.target

    @goToStep(3, button.value)

  goToStep: (step, subStep)->
    @props.step.set step
    @props.subStep.set subStep

  addNote: ->
    @setState({
      values: []
    }, =>
      @props.notes.push [@props.currentAnswers]
      @props.resetCurrentAnswers()
      @goToStep(1, 0)
    )

  cancelNote: ->
    @goToStep(1, 0)
    @props.resetCurrentAnswers()
    @clearMultipleSelection()

  finishNote: ->
    console?.log 'send to classification', @props.classification
    @props.classification.annotate @props.notes.value
    @sendClassification()
    @goToStep(steps.length - 1, 0)
    @props.disableSkip()

  nextSubject: ->
    @props.notes.set []
    @props.resetCurrentAnswers()
    if @props.skipImages is true
      @goToStep(1, 0)
    else
      @goToStep(0, 0)
    @props.showLoader()
    @props.enableSkip()
    Subject.next()

  sendClassification: ->
    @props.classification.send()
    console?.log 'classification send'

  render: ->
    cancelClasses = classnames
      'cancel': true
      'hide': @props.step.value <= 1 or @props.step.value is steps.length - 1

    addDisabled = @state.values.length is 0

    addAndCancelStyle = switch
      when @props.step.value is 2 and window.innerWidth <= 400 then "top": "-110px"
      when @props.step.value is 2 and window.innerWidth > 400 and window.innerWidth <=450 then "top": "-95px"
      when @props.step.value is 3 and window.innerWidth <= 400 then "top": "-130px"
      when @props.step.value is 3 and window.innerWidth > 400 and window.innerWidth <= 450 then "top": "-115px"
      when @props.subStep.value is 3 and window.innerWidth > 450 then "marginTop": "52.5px"

    addClasses = classnames
      'disabled': addDisabled
      'done': true
      'hidden': @props.step.value is 2 or @props.subStep.value < 2
      'hide': @props.step.value < 2 or @props.step.value is steps.length - 1

    stepButtons =
      if @props.step.value > 2 and @props.step.value isnt steps.length - 1
        firstStepClasses = classnames
          'step-button': true
          'step-active': @props.step.value is 2
          'step-complete': @props.step.value > 2

        if @props.currentAnswers.animal is chimp
          subSteps = steps[3].map (step, i) =>
            stepBtnDisabled = _.values(@props.currentAnswers).length < i + 2
            stepBtnClasses = classnames
              'step-button': true
              'step-active': @props.subStep.value is i
              'step-complete': i - 1 < @props.subStep.value - 1
              'disabled': stepBtnDisabled

            if i isnt steps[3].length - 1
              <span key={i}>
                <button className={stepBtnClasses} value={i} onClick={@goToSubStep} disabled={stepBtnDisabled}>{i+2}</button>
                <img src="./assets/small-dot.svg" alt="" />
              </span>
        else
          stepBtnClasses = classnames
            'step-button': true
            'step-active': @props.subStep.value is 3

          subSteps =
            <span>
              <button className={stepBtnClasses} value="3" onClick={@goToSubStep}>2</button>
              <img src="./assets/small-dot.svg" alt="" />
            </span>

        <div className="step-buttons">
          <small>Steps</small>
          <span>
            <button className={firstStepClasses} value="2" onClick={@goToAnimalStep}>1</button>
            <img src="./assets/small-dot.svg" alt="" />
          </span>
          {subSteps}
        </div>

    step = for name, step of steps[@props.step.value][@props.subStep.value]
      buttons = step.options.map (option, i) =>
        currentAnswersValues = _.values(@props.currentAnswers)
        currentAnswersValues = _.flatten(currentAnswersValues)
        disabled =
          switch
            when @props.notes.value.length is 0 and option is steps[1][0].annotation.options[2] then true
            when @props.notes.value.length > 0 and option is steps[1][0].annotation.options[0] then true

        classes = classnames
          'btn-active': option in currentAnswersValues
          'disabled finish-disabled': @props.notes.value.length is 0 and option is steps[1][0].annotation.options[2]
          'disabled nothing-disabled': @props.notes.value.length > 0 and option is steps[1][0].annotation.options[0]

        <button className={classes} key={i} id="#{name}-#{i}" name={name} value={option} onClick={@onButtonClick} disabled={disabled}>
          {option}
        </button>

      <div key={name} className={name}>
        {unless step.question is null
          <div className="step-top">
            <div className="step-question">
              <p className="question">{step.question}</p>
              <p className="tip">Not sure? Check out the <a className="guide-link" onClick={@props.onClickGuide}>Field Guide</a>!</p>
            </div>
            {stepButtons}
          </div>}
        <div className="step-bottom">
          <button className={cancelClasses} onClick={@cancelNote} style={addAndCancelStyle}>Cancel</button>
          <div className="buttons-container">
            {buttons}
            {<p className="tip">Please add a separate annotation for each chimpanzee.</p> if @props.currentAnswers.animal is chimp}
          </div>
          <button className={addClasses} onClick={@addNote} disabled={addDisabled} style={addAndCancelStyle}>Done</button>
        </div>
      </div>

    <div className="step">
      {step}
    </div>

module.exports = Step