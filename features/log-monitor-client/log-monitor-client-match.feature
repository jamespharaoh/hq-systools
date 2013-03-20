Feature: Log monitor client correctly reports matching lines

  Background:
    Given a file "default.config":
      """
      <log-monitor-client-config>
        <cache path="cache"/>
        <client class="class" host="host"/>
        <server url="${server-url}"/>
        <service name="service">
          <fileset>
            <scan glob="*.log"/>
            <match type="critical" regex="CRITICAL"/>
            <match type="warning" regex="WARNING"/>
          </fileset>
        </service>
      </log-monitor-client-config>
      """

  Scenario: Ignore lines which don't match any pattern

    Given a file "logfile.log":
       """
       NOTICE Not an error
       """

     When I run log-monitor-client with config "default.config"

     Then no events should be submitted

  Scenario: Produce events for lines which match a pattern

    Given a file "logfile.log":
       """
       WARNING This is a warning
       """

     When I run log-monitor-client with config "default.config"

     Then the following events should be submitted:
       """
       {
         type: warning,
         source: { class: class, host: host, service: service },
         location: { file: logfile.log, line: 0 },
         lines: {
           before: [],
           matching: WARNING This is a warning,
           after: [],
         },
       }
       """

  Scenario: Only produce an event for the first matched pattern

    Given a file "logfile.log":
       """
       CRITICAL WARNING This is a confused log entry
       """

    When I run log-monitor-client with config "default.config"

    Then the following events should be submitted:
      """
      {
        type: critical,
        source: { class: class, host: host, service: service },
        location: { file: logfile.log, line: 0 },
        lines: {
          before: [],
          matching: CRITICAL WARNING This is a confused log entry,
          after: [],
        },
      }
      """
