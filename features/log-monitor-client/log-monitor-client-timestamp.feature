Feature: Log monitor client does not open files whose timestamps have not changed

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
    When I run log-monitor-client with config "default.config"
    Then no events should be submitted

  Scenario: Timestamp changed

    Given a file "logfile.log":
      """
      NOTICE This is a notice
      """
    And I have run log-monitor-client with config "default.config"
    And I have updated file "logfile.log":
      """
      NOTICE This is a notice
      CRITICAL This is a critical error
      """

    When I run log-monitor-client with config "default.config"

    Then the following events should be submitted:
      """
      {
        type: critical,
        source: { class: class, host: host, service: service },
        location: { file: logfile.log, line: 1 },
        prefix: [],
        line: "CRITICAL This is a critical error",
        suffix: [],
      }
      """

  Scenario: Timestamp unchanged

    Given a file "logfile.log":
      """
      NOTICE This is a notice
      """
    And I have run log-monitor-client with config "default.config"
    And I have updated file "logfile.log" without changing the timestamp:
      """
      NOTICE This is a notice
      CRITICAL This is a critical error
      """

    When I run log-monitor-client with config "default.config"

    Then no events should be submitted
