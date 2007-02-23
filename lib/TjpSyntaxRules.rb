#
# TjpSyntaxRules - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

# This module contains the rule definition for the TJP syntax. Every rule is
# put in a function who's name must start with rule_. The functions are not
# necessary but make the file more readable and receptable to syntax folding.
module TjpSyntaxRules

  def initRules
    # Call all functions that start with 'rule_' to initialize the rules.
    methods.each do |m|
      send(m) if m[0, 5] == 'rule_'
    end
  end


  def rule_allocationAttribute
    newRule('allocationAttribute')
    optional
    repeatable
    newPattern(%w( _alternative !resourceId !moreAlternatives ), Proc.new {
      [ 'alternative', [ @val[1] ] + @val[2] ]
    })
    newPattern(%w( _select $ID ), Proc.new {
      modes = %w( maxloaded minloaded minallocated order random )
      if (index = modes.index(@val[1])).nil?
        error("Selection mode must be one of #{modes.join(', ')}")
      end
      [ 'select', @val[1] ]
    })
    singlePattern("_persistent")
    singlePattern("_mandatory")
  end

  def rule_allocationAttributes
    newRule('allocationAttributes')
    optional
    newPattern(%w( _{ !allocationAttribute _} ), Proc.new {
      @val[1]
    })
  end

  def rule_argumentList
    newRule('argumentList')
    optional
    newPattern(%w( _( !operation !moreArguments _) ), Proc.new {
      [ @val[0] ] + @val[1].nil? ? [] : @val[1]
    })
  end

  def rule_calendarDuration
    newRule('calendarDuration')
    newPattern(%w( !number !durationUnit ), Proc.new {
      convFactors = [ 60, # minutes
                      60 * 60, # hours
                      60 * 60 * 24, # days
                      60 * 60 * 24 * 7, # weeks
                      60 * 60 * 24 * 30.4167, # months
                      60 * 60 * 24 * 365 # years
                     ]
      (@val[0] * convFactors[@val[1]] / @project['scheduleGranularity']).to_i
    })
  end

  def rule_columnBody
    newRule('columnBody')
    optional
    newPattern(%w( _{ !columnOptions _} ), Proc.new {
      @val[1]
    })
  end

  def rule_columnDef
    newRule('columnDef')
    newPattern(%w( !columnId !columnBody ), Proc.new {
      @val[0]
    })
  end

  def rule_columnId
    newRule('columnId')
    newPattern(%w( $ID ), Proc.new {
      if (title = @reportElement.defaultColumnTitle(@val[0])).nil?
        error("Unknown column #{@val[0]}")
      end
      @column = TableColumnDefinition.new(@val[0], title)
    })
  end

  def rule_columnOptions
    newRule('columnOptions')
    optional
    repeatable
    newPattern(%w( _title $STRING ), Proc.new {
      @column.title = @val[1]
    })
  end

  def rule_declareFlagList
    newListRule('declareFlagList', '$ID')
  end

  def rule_durationUnit
    newRule('durationUnit')
    newPattern(%w( $ID ), Proc.new {
      units = [ 'min', 'h', 'd', 'w', 'm', 'y' ]
      res = units.index(@val[0])
      if res.nil?
        error("Unit must be one of #{units.join(', ')}")
      end
      res
    })
  end

  def rule_extendAttributes
    newRule('extendAttributes')
    optional
    repeatable
    newPattern(%w( _date !extendId  $STRING !extendOptionsBody ), Proc.new {
      # Extend the propertySet definition and parser rules
      if extendPropertySetDefinition(DateAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$DATE' ], Proc.new {
            @property[@val[0], @scenarioIdx] = @val[1]
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$DATE' ], Proc.new {
            @property.set(@val[0], @val[1])
          }))
      end
    })
    newPattern(%w( _reference $STRING !extendOptionsBody ), Proc.new {
      # Extend the propertySet definition and parser rules
      reference = ReferenceAttribute.new
      reference.set([ @val[1], @val[2].nil? ? nil : @val[2][0] ])
      if extendPropertySetDefinition(ReferenceAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], Proc.new {
            @property[@val[0], @scenarioIdx] = reference
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], Proc.new {
            @property.set(reference)
          }))
      end
    })
    newPattern(%w( _text !extendId $STRING !extendOptionsBody ), Proc.new {
      # Extend the propertySet definition and parser rules
      if extendPropertySetDefinition(StringAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING' ], Proc.new {
            @property[@val[0], @scenarioIdx] = @val[1]
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING' ], Proc.new {
            @property.set(@val[0], @val[1])
          }))
      end
    })
  end

  def rule_extendBody
    newRule('extendBody')
    optional
    newPattern(%w( _{ !extendAttributes _} ), Proc.new {
      @val[1]
    })
  end

  def rule_extendId
    newRule('extendId')
    newPattern(%w( $ID ), Proc.new {
      unless (?A..?Z) === @val[0][0]
        error("User defined attributes IDs must start with a capital letter")
      end
      @val[0]
    })
  end

  def rule_extendOptions
    newRule('extendOptions')
    optional
    repeatable
    singlePattern("_inherit")
    singlePattern("_scenariospecific")
  end

  def rule_extendOptionsBody
    newRule('extendOptionsBody')
    optional
    newPattern(%w( _{ !extendOptions _} ), Proc.new {
      @val[1]
    })
  end

  def rule_extendProperty
    newRule('extendProperty')
    newPattern(%w( $ID ), Proc.new {
      case @val[0]
      when 'task'
        @ruleToExtend = @rules['taskAttributes']
        @ruleToExtendWithScenario = @rules['taskScenarioAttributes']
        @propertySet = @project.tasks
      when 'resource'
        @ruleToExtend = @rules['resourceAttributes']
        @ruleToExtendWithScenario = @rules['resourceScenarioAttributes']
        @propertySet = @project.resources
      else
        error("Extendable property expected: task or resource")
      end
    })
  end

  def rule_flag
    newRule('flag')
    newPattern(%w( $ID ), Proc.new {
      unless @project['flags'].include?(@val[0])
        error("Undeclared flag #{@val[0]}")
      end
      @val[0]
    })
  end

  def rule_flagList
    newListRule('flagList', '!flag')
  end

  def rule_include
    newRule('include')
    newPattern(%w( _include $STRING ), Proc.new {
      @scanner.include(@val[1])
    })
  end

  def rule_interval
    newRule('interval')
    newPattern(%w( $DATE !intervalEnd ), Proc.new {
      mode = @val[1][0]
      endSpec = @val[1][1]
      if mode == 0
        Interval.new(@val[0], endSpec)
      else
        Interval.new(@val[0], @val[0] + endSpec)
      end
    })
  end

  def rule_intervalDuration
    newRule('intervalDuration')
    newPattern(%w( $INTEGER !durationUnit ), Proc.new {
      convFactors = [ 60, # minutes
                      60 * 60, # hours
                      60 * 60 * 24, # days
                      60 * 60 * 24 * 7, # weeks
                      60 * 60 * 24 * 30.4167, # months
                      60 * 60 * 24 * 365 # years
                     ]
      (@val[0] * convFactors[@val[1]]).to_i
    })
  end

  def rule_intervalEnd
    newRule('intervalEnd')
    newPattern([ '_ - ', '$DATE' ], Proc.new {
      [ 0, @val[1] ]
    })
    newPattern(%w( _+ !intervalDuration ), Proc.new {
      [ 1, @val[1] ]
    })
  end

  def rule_intervals
    newListRule('intervals', '!interval')
  end

  def rule_listOfDays
    newRule('listOfDays')
    newPattern(%w( !weekDayInterval !moreListOfDays), Proc.new {
      weekDays = Array.new(7, false)
      ([ @val[0] ] + @val[1]).each do |dayList|
        0.upto(6) { |i| weekDays[i] = true if dayList[i] }
      end
      weekDays
    })
  end

  def rule_listOfTimes
    newRule('listOfTimes')
    newPattern(%w( _off ), Proc.new {
      [ ]
    })
    newPattern(%w( !timeInterval !moreTimeIntervals ), Proc.new {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_logicalExpression
    newRule('logicalExpression')
    newPattern(%w( !operation ), Proc.new {
      LogicalExpression.new(@val[0], @scanner.fileName, @scanner.lineNo)
    })
  end

  def rule_moreAlternatives
    newCommaListRule('moreAlternatives', '!resourceId')
  end

  def rule_moreArguments
    newCommaListRule('moreArguments', '!operation')
  end

  def rule_moreColumnDef
    newCommaListRule('moreColumnDef', '!columnDef')
  end

  def rule_moreListOfDays
    newCommaListRule('moreListOfDays', '!weekDayInterval')
  end

  def rule_moreTasks
    newCommaListRule('moreTasks', '!taskList')
  end

  def rule_moreTimeIntervals
    newCommaListRule('moreTimeIntervals', '!timeInterval')
  end

  def rule_number
    newRule('number')
    singlePattern("$INTEGER")
    singlePattern("$FLOAT")
  end

  def rule_operand
    newRule('operand')
    newPattern(%w( _( !operation _) ), Proc.new {
      @val[1]
    })
    newPattern(%w( _~ !operand ), Proc.new {
      operation = LogicalOperation.new(@val[1])
      operation.operator = '~'
      operation
    })
    newPattern(%w( $ABSOLUTE_ID ), Proc.new {
      if @val[0].count('.') > 1
        error "Attributes must be specified as <scenarioID>.<attribute>"
      end
      scenario, attribute = @val[0].split('.')
      if (scenarioIdx = @project.scenarioIdx(scenario)).nil?
        error "Unknown scenario ID #{scenario}"
      end
      LogicalAttribute.new(attribute, scenarioIdx)
    })
    newPattern(%w( $DATE ), Proc.new {
      LogicalOperation.new(@val[0])
    })
    newPattern(%w( $ID !argumentList ), Proc.new {
      if @val[1].nil?
        unless @project['flags'].include?(@val[0])
          error "Undeclared flag #{@val[0]}"
        end
        operation = LogicalFlag.new(@val[0])
      else
        # TODO: add support for old functions
      end
    })
    newPattern(%w( $INTEGER ), Proc.new {
      LogicalOperation.new(@val[0])
    })
    newPattern(%w( $STRING ), Proc.new {
      LogicalOperation.new(@val[0])
    })
  end

  def rule_operation
    newRule('operation')
    newPattern(%w( !operand !operatorAndOperand ), Proc.new {
      operation = LogicalOperation.new(@val[0])
      unless @val[1].nil?
        operation.operator = @val[1][0]
        operation.operand2 = @val[1][1]
      end
      operation
    })
  end

  def rule_operatorAndOperand
    newRule('operatorAndOperand')
    optional
    operandPattern("|")
    operandPattern("&")
    operandPattern(">")
    operandPattern("<")
    operandPattern("=")
    operandPattern(">=")
    operandPattern("<=")
  end

  def rule_project
    newRule('project')
    newPattern(%w( !projectHeader !projectBody !properties ), Proc.new {
      @val[0]
    })
  end

  def rule_projectBody
    newRule('projectBody')
    optional
    newPattern(%w( _{ !projectBodyAttributes _} ))
  end

  def rule_projectBodyAttributes
    newRule('projectBodyAttributes')
    repeatable
    optional
    newPattern(%w( _currencyformat $STRING $STRING $STRING $STRING $STRING ),
        Proc.new {
      @project['currencyformat'] = RealFormat.new(@val.slice(1, 5))
    })
    newPattern(%w( _currency $STRING ), Proc.new {
      @project['currency'] = @val[1]
    })
    newPattern(%w( _dailyworkinghours !number ), Proc.new {
      @project['dailyworkinghours'] = @val[1]
    })
    newPattern(%w( _extend !extendProperty !extendBody ), Proc.new {
      updateParserTables
    })
    newPattern(%w( !include ))
    newPattern(%w( _now $DATE ), Proc.new {
      @project['now'] = @val[1]
    })
    newPattern(%w( _numberformat $STRING $STRING $STRING $STRING $STRING ),
        Proc.new {
      @project['numberformat'] = RealFormat.new(@val.slice(1, 5))
    })
    newPattern(%w( !scenario ))
    newPattern(%w( _shorttimeformat $STRING ), Proc.new {
      @project['shorttimeformat'] = @val[1]
    })
    newPattern(%w( _timeformat $STRING ), Proc.new {
      @project['timeformat'] = @val[1]
    })
    newPattern(%w( !timezone ), Proc.new {
      @project['timezone'] = @val[1]
    })
    newPattern(%w( _timingresolution !calendarDuration ), Proc.new {
      error('Timing resolution must be at least 5 min.') if @val[1] < 60 * 5
      error('Timing resolution must be 1 hour or less.') if @val[1] > 60 * 60
      @project['scheduleGranularity'] = @val[1]
    })
    newPattern(%w( _weekstartsmonday ), Proc.new {
      @project['weekstartsmonday'] = true
    })
    newPattern(%w( _weekstartssunday ), Proc.new {
      @project['weekstartsmonday'] = false
    })
    newPattern(%w( _yearlyworkingdays !number ), Proc.new {
      @project['yearlyworkingdays'] = @val[1]
    })
  end

  def rule_projectHeader
    newRule('projectHeader')
    newPattern(%w( _project $ID $STRING $STRING !interval ), Proc.new {
      @project = Project.new(@val[1], @val[2], @val[3])
      @project['start'] = @val[4].start
      @project['end'] = @val[4].end
      @property = nil
      @scenario = nil
      @project
    })
  end

  def rule_properties
    newRule('properties')
    repeatable
    newPattern(%w( _copyright $STRING ), Proc.new {
      @project['copyright'] = @val[1]
    })
    newPattern(%w( !include ))
    newPattern(%w( _flags !declareFlagList ), Proc.new {
      unless @project['flags'].include?(@val[1])
        @project['flags'] += @val[1]
      end
    })
    newPattern(%w( !report ))
    newPattern(%w( !resource ))
    newPattern(%w( !task ))
    newPattern(%w( _vacation !vacationName !intervals ), Proc.new {
      @project['vacations'] = @project['vacations'] + @val[2]
    })
    newPattern(%w( !workinghours ))
  end

  def rule_referenceAttributes
    newRule('referenceAttributes')
    optional
    repeatable
    newPattern(%w( _label $STRING ), Proc.new {
      @val[1]
    })
  end

  def rule_referenceBody
    newRule('referenceBody')
    optional
    newPattern(%w( _{ !referenceAttributes _} ), Proc.new {
      @val[1]
    })
  end

  def rule_report
    newRule('report')
    newPattern(%w( !reportHeader !reportBody ))
  end

  def rule_reportAttributes
    newRule('reportAttributes')
    optional
    repeatable
    newPattern(%w( _columns !columnDef !moreColumnDef ), Proc.new {
      columns = [ @val[1] ]
      columns += @val[2] if @val[2]
      @reportElement.columns = columns
    })
    newPattern(%w( _end !valDate ), Proc.new {
      @reportElement.end = @val[1]
    })
    newPattern(%w( _headline $STRING ), Proc.new {
      @reportElement.headline = @val[1]
    })
    newPattern(%w( _hideresource !logicalExpression ), Proc.new {
      @reportElement.hideResource = @val[1]
    })
    newPattern(%w( _hidetask !logicalExpression ), Proc.new {
      @reportElement.hideTask = @val[1]
    })
    newPattern(%w( _period !valInterval), Proc.new {
      @reportElement.start = @val[1].start
      @reportElement.end = @val[1].end
    })
    newPattern(%w( _rolluptask !logicalExpression ), Proc.new {
      @reportElement.rollupTask = @val[1]
    })
    newPattern(%w( _scenarios !scenarioIdList ), Proc.new {
      # Don't include disabled scenarios in the report
      @val[1].delete_if { |sc| !@project.scenario(sc).get('enabled') }
      @reportElement.scenarios = @val[1]
    })
    newPattern(%w( _sortresources !sortCriteria ), Proc.new {
      @reportElement.sortResources = @val[1]
    })
    newPattern(%w( _sorttasks !sortCriteria ), Proc.new {
      @reportElement.sortTasks = @val[1]
    })
    newPattern(%w( _start !valDate ), Proc.new {
      @reportElement.start = @val[1]
    })
    newPattern(%w( _taskroot !taskRootId), Proc.new {
      if (task = @project.task(@val[1])).nil?
        error "Unknown task #{@val[1]}"
      end
      @reportElement.taskRoot = task
    })
    newPattern(%w( _timeformat $STRING ), Proc.new {
      @reportElement.timeformat = @val[1]
    })
  end

  def rule_reportBody
    newRule('reportBody')
    optional
    newPattern(%w( _{ !reportAttributes _} ))
  end

  def rule_reportHeader
    newRule('reportHeader')
    newPattern(%w( !reportType $STRING ), Proc.new {
      case @val[0]
      when 'export'
        @report = ExportReport.new(@project, @val[1])
      when 'htmltaskreport'
        @report = HTMLTaskReport.new(@project, @val[1])
        @reportElement = @report.element
      when 'htmlresourcereport'
        @report = HTMLResourceReport.new(@project, @val[1])
        @reportElement = @report.element
      end
    })
  end

  def rule_reportType
    newRule('reportType')
    singlePattern("_export")
    singlePattern("_htmltaskreport")
    singlePattern("_htmlresourcereport")
  end

  def rule_resource
    newRule('resource')
    newPattern(%w( !resourceHeader !resourceBody ), Proc.new {
       @property = @property.parent
    })
  end

  def rule_resourceAllocation
    newRule('resourceAllocation')
    newPattern(%w( !resourceId !allocationAttributes ), Proc.new {
      candidates = [ @val[0] ]
      selectionMode = 1 # Defaults to min. allocation probability
      mandatory = false
      persistant = false
      if @val[1]
        @val[1].each do |attribute|
          case attribute[0]
          when 'alternative'
            candidates += attribute[1]
          when 'persistant'
            persistant = true
          when 'mandatory'
            mandatory = true
          end
        end
      end
      Allocation.new(candidates, selectionMode, persistant, mandatory)
    })
  end

  def rule_resourceAllocations
    newListRule('resourceAllocations', '!resourceAllocation')
  end

  def rule_resourceAttributes
    newRule('resourceAttributes')
    repeatable
    optional
    newPattern(%w( $ID_WITH_COLON !taskScenarioAttributes ), Proc.new {
      if (@scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error("Unknown scenario: @val[0]")
      end
    })
    newPattern(%w( !resource ))
    newPattern(%w( !resourceScenarioAttributes ))
    newPattern(%w( !workinghours ))
    # Other attributes will be added automatically.
  end

  def rule_resourceBody
    newRule('resourceBody')
    optional
    newPattern(%w( _{ !resourceAttributes _} ))
  end

  def rule_resourceId
    newRule('resourceId')
    newPattern(%w( $ID ), Proc.new {
      if (resource = @project.resource(@val[0])).nil?
        error("Resource ID expected")
      end
      resource
    })
  end

  def rule_resourceHeader
    newRule('resourceHeader')
    newPattern(%w( _resource $ID $STRING ), Proc.new {
      @property = Resource.new(@project, @val[1], @val[2], @property)
      @property.inheritAttributes
    })
  end

  def rule_resourceScenarioAttributes
    newRule('resourceScenarioAttributes')
    newPattern(%w( _flags !flagList ), Proc.new {
      @property['flags', @scenarioIdx] += @val[1]
    })
    newPattern(%w( _vacation !vacationName !intervals ), Proc.new {
      @resource['vacations', @scenarioIdx] =
        @resource['vacations', @scenarioIdx ] + @val[2]
    })
    # Other attributes will be added automatically.
  end

  def rule_scenario
    newRule('scenario')
    newPattern(%w( !scenarioHeader !scenarioBody ), Proc.new {
      @scenario = @scenario.parent
    })
  end

  def rule_scenarioAttributes
    newRule('scenarioAttributes')
    optional
    repeatable
    newPattern(%w( !scenario ))
    # Other attributes will be added automatically.
  end

  def rule_scenarioBody
    newRule('scenarioBody')
    optional
    newPattern(%w( _{ !scenarioAttributes _} ))
  end

  def rule_scenarioHeader
    newRule('scenarioHeader')
    newPattern(%w( _scenario $ID $STRING ), Proc.new {
      # If this is the top-level scenario, we must delete the default scenario
      # first.
      @project.scenarios.clearProperties if @scenario.nil?
      @scenario = Scenario.new(@project, @val[1], @val[2], @scenario)
    })
  end

  def rule_scenarioId
    newRule('scenarioId')
    newPattern(%w( $ID_WITH_COLON ), Proc.new {
      if (@scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error("Unknown scenario: @val[0]")
      end
    })
  end

  def rule_scenarioIdList
    newListRule('scenarioIdList', '!scenarioIdx')
  end

  def rule_scenarioIdx
    newRule('scenarioIdx')
    newPattern(%w( $ID ), Proc.new {
      if (scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error("Unknown scenario #{@val[1]}")
      end
      scenarioIdx
    })
  end

  def rule_sortCriteria
    newListRule('sortCriteria', '!sortCriterium')
  end

  def rule_sortCriterium
    newRule('sortCriterium')
    newPattern(%w( $ABSOLUTE_ID ), Proc.new {
      args = @val[0].split('.')
      case args.length
      when 2
        scenario = -1
        direction = args[1]
        attribute = args[0]
      when 3
        if (scenario = @project.scenarioIdx(args[0])).nil?
          error "Unknown scenario #{args[0]} in sorting criterium"
        end
        attribute = args[1]
        if args[2] != 'up' && args[2] != 'down'
          error "Sorting direction must be 'up' or 'down'"
        end
        direction = args[2] == 'up'
      else
        error("Sorting criterium expected (e.g. tree, start.up or " +
              "plan.end.down).")
      end
      [ attribute, direction, scenario ]
    })
    newPattern(%w( $ID ), Proc.new {
      if @val[0] != 'tree'
        error("Sorting criterium expected (e.g. tree, start.up or " +
              "plan.end.down).")
      end
      [ 'tree', true, -1 ]
    })
  end

  def rule_task
    newRule('task')
    newPattern(%w( !taskHeader !taskBody ), Proc.new {
      @property = @property.parent
    })
  end

  def rule_taskAttributes
    newRule('taskAttributes')
    repeatable
    optional
    newPattern(%w( !task ))
    newPattern(%w( !taskScenarioAttributes ))
    newPattern(%w( !scenarioId !taskScenarioAttributes ), Proc.new {
      @scenarioIdx = 0
    })
    # Other attributes will be added automatically.
  end

  def rule_taskBody
    newRule('taskBody')
    optional
    newPattern(%w( _{ !taskAttributes _} ))
  end

  def rule_taskHeader
    newRule('taskHeader')
    newPattern(%w( _task $ID $STRING ), Proc.new {
      @property = Task.new(@project, @val[1], @val[2], @property)
      @property.inheritAttributes
      @scenarioIdx = 0
    })
  end

  def rule_taskId
    newRule('taskId')
    singlePattern("$ABSOLUTE_ID")
    singlePattern("$ID")
    newPattern(%w( $RELATIVE_ID ), Proc.new {
      task = @property
      id = @val[0]
      while task && id[0] == ?!
        id = id.slice(1, id.length)
        task = task.parent
      end
      error("Too many '!' for relative task in this context.") if id[0] == ?!
      if task
        task.id + '.' + id
      else
        id
      end
    })
  end

  def rule_taskList
    newRule('taskList')
    newPattern(%w( !taskId !moreTasks ), Proc.new {
      [ TaskDependency.new(@val[0]) ] + @val[1]
    })
  end

  def rule_taskRootId
    newRule('taskRootId')
    singlePattern("$ABSOLUTE_ID")
    singlePattern("$ID")
  end

  def rule_taskScenarioAttributes
    newRule('taskScenarioAttributes')
    newPattern(%w( _allocate !resourceAllocations ), Proc.new {
      # Don't use << operator here so the 'provided' flag gets set properly.
      @property['allocate', @scenarioIdx] =
        @property['allocate', @scenarioIdx] + @val[1]
    })
    newPattern(%w( _depends !taskList ), Proc.new {
      @property['depends', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _duration !calendarDuration ), Proc.new {
      @property['duration', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _effort !workingDuration ), Proc.new {
      @property['effort', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _end !valDate ), Proc.new {
      @property['end', @scenarioIdx] = @val[1]
      @property['forward'] = false
    })
    newPattern(%w( _flags !flagList ), Proc.new {
      @property['flags', @scenarioIdx] += @val[1]
    })
    newPattern(%w( _length !workingDuration ), Proc.new {
      @property['length', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _priority $INTEGER ), Proc.new {
      if @val[1] < 0 || @val[1] > 1000
        error("Priority must have a value between 0 and 1000")
      end
    })
    newPattern(%w( _start !valDate), Proc.new {
      @property['start', @scenarioIdx] = @val[1]
      @property['forward', @scenarioIdx] = true
    })
    # Other attributes will be added automatically.
  end

  def rule_timeInterval
    newRule('timeInterval')
    newPattern([ '$TIME', '_ - ', '$TIME' ], Proc.new {
      if @val[0] >= @val[2]
        error("End time of interval must be larger than start time")
      end
      [ @val[0], @val[2] ]
    })
  end

  def rule_timezone
    newRule('timezone')
    newPattern(%w( _timezone $STRING ))
  end

  def rule_vacationName
    newRule('vacationName')
    optional
    newPattern(%w( $STRING )) # We just throw the name away
  end

  def rule_valDate
    newRule('valDate')
    newPattern(%w( $DATE ), Proc.new {
      if @val[0] < @project['start'] || @val[0] > @project['end']
        error("Date must be within the project time frame " +
          "#{@project['start']} +  - #{@project['end']}")
      end
      @val[0]
    })
  end

  def rule_valInterval
    newRule('valInterval')
    newPattern(%w( $DATE !intervalEnd ), Proc.new {
      mode = @val[1][0]
      endSpec = @val[1][1]
      if mode == 0
        iv = Interval.new(@val[0], endSpec)
      else
        iv = Interval.new(@val[0], @val[0] + endSpec)
      end
      # Make sure the interval is within the project time frame.
      if iv.start < @project['start'] || iv.start >= @project['end']
        error("Start date #{iv.start} must be within the project time frame")
      end
      if iv.end <= @project['start'] || iv.end > @project['end']
        error("End date #{iv.end} must be within the project time frame")
      end
      iv
    })
  end

  def rule_weekDayInterval
    newRule('weekDayInterval')
    newPattern(%w( $ID !weekDayIntervalEnd ), Proc.new {
      weekdays = Array.new(7, false)
      if @val[1].nil?
        weekdays[weekDay(@val[0])] = true
      else
        first = weekDay(@val[0])
        last = weekDay(@val[1])
        first.upto(last + 7) { |i| weekdays[i % 7] = true }
      end

      weekdays
    })
  end

  def rule_weekDayIntervalEnd
    newRule('weekDayIntervalEnd')
    optional
    newPattern([ '_ - ', '$ID' ], Proc.new {
      @val[1]
    })
  end

  def rule_workingDuration
    newRule('workingDuration')
    newPattern(%w( !number !durationUnit ), Proc.new {
      convFactors = [ 60, # minutes
                      60 * 60, # hours
                      60 * 60 * @project['dailyworkinghours'], # days
                      60 * 60 * @project['dailyworkinghours'] *
                      (@project['yearlyworkingdays'] / 52.1429), # weeks
                      60 * 60 * @project['dailyworkinghours'] *
                      (@project['yearlyworkingdays'] / 12), # months
                      60 * 60 * @project['dailyworkinghours'] *
                      @project['yearlyworkingdays'] # years
                    ]
      (@val[0] * convFactors[@val[1]] /
       @project['scheduleGranularity']).round.to_i
    })
  end

  def rule_workinghours
    newRule('workinghours')
    newPattern(%w( _workinghours !listOfDays !listOfTimes), Proc.new {
      wh = @property.nil? ? @project['workinghours'] : @property['workinghours']
      0.upto(6) { |i| wh.setWorkingHours(i, @val[2]) if @val[1][i] }
    })
  end

end

