Feature: Log monitor client does detects rotated log files

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

  Scenario: Log file rotated

    Given a file "logfile.log":
      """
      WARNING This is an old warning 0
      """
    And I have run log-monitor-client with config "default.config"
    And I have updated file "logfile.log" changing the timestamp:
      """
      WARNING This is a new warning 0
      WARNING This is a new warning 1
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
          matching: WARNING This is a new warning 0,
          after: [],
        },
      },
      {
        type: warning,
        source: { class: class, host: host, service: service },
        location: { file: logfile.log, line: 1 },
        lines: {
          before: [],
          matching: WARNING This is a new warning 1,
          after: [],
        },
      }
      """

  Scenario: Log file not rotated

    Given a file "logfile.log":
      """
      WARNING This is an old warning 0
      """
    And I have run log-monitor-client with config "default.config"
    And I have updated file "logfile.log" changing the timestamp:
      """
      WARNING This is an old warning 0
      WARNING This is a new warning 1
      """
    When I run log-monitor-client with config "default.config"

    Then the following events should be submitted:
      """
      {
        type: warning,
        source: { class: class, host: host, service: service },
        location: { file: logfile.log, line: 1 },
        lines: {
          before: [],
          matching: WARNING This is a new warning 1,
          after: [],
        },
      }
      """
