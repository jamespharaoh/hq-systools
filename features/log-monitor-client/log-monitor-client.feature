Feature: Log monitor client

  Background:
    Given a config file "default":
      """
      <log-monitor-client-config>
        <client class="class" host="host"/>
        <server url="${server-url}"/>
        <service name="service">
          <fileset>
            <scan glob="*"/>
            <match type="critical" regex="CRITICAL"/>
            <match type="warning" regex="WARNING"/>
          </fileset>
        </service>
      </log-monitor-client-config>
      """

  Scenario: Ignore lines which don't match any pattern
    Given a logfile "logfile":
       """
       NOTICE Not an error
       """
     When I run log-monitor-client with config "default"
     Then no events should be submitted

  Scenario: Produce events for lines which match a pattern
    Given a logfile "logfile":
       """
       WARNING This is a warning
       """
     When I run log-monitor-client with config "default"
     Then the following events should be submitted:
       """
       {
         type: warning,
         source: { class: class, host: host, service: service },
         location: { file: logfile, line: 0 },
         prefix: [],
         line: "WARNING This is a warning",
         suffix: [],
       }
       """

  Scenario: Only produce an event for the first matched pattern
    Given a logfile "logfile":
       """
       CRITICAL WARNING This is a confused log entry
       """
     When I run log-monitor-client with config "default"
     Then the following events should be submitted:
       """
       {
         type: critical,
         source: { class: class, host: host, service: service },
         location: { file: logfile, line: 0 },
         prefix: [],
         line: "CRITICAL WARNING This is a confused log entry",
         suffix: [],
       }
       """
