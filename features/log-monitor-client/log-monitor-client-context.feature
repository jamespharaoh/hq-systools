Feature: Log monitor client provides context lines correctly
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
            <match type="critical" regex="CRITICAL" before="2" after="2"/>
            <match type="warning" regex="WARNING" before="2" after="2"/>
          </fileset>
        </service>
      </log-monitor-client-config>
      """

  Scenario: Middle of large file

    Given a file "logfile.log":
      """
      NOTICE line 0
      NOTICE line 1
      NOTICE line 2
      WARNING line 3
      NOTICE line 4
      NOTICE line 5
      NOTICE line 6
      """

    When I run log-monitor-client with config "default.config"

    Then the following events should be submitted:
      """
      {
        type: warning,
        source: { class: class, host: host, service: service },
        location: { file: logfile.log, line: 3 },
        lines: {
          before: [
            NOTICE line 1,
            NOTICE line 2,
          ],
          matching: WARNING line 3,
          after: [
            NOTICE line 4,
            NOTICE line 5,
          ],
        }
      }
      """

  Scenario: Start of large file

    Given a file "logfile.log":
      """
      NOTICE line 0
      WARNING line 1
      NOTICE line 2
      NOTICE line 3
      NOTICE line 4
      """

    When I run log-monitor-client with config "default.config"

    Then the following events should be submitted:
      """
      {
        type: warning,
        source: { class: class, host: host, service: service },
        location: { file: logfile.log, line: 1 },
        lines: {
          before: [
            NOTICE line 0,
          ],
          matching: WARNING line 1,
          after: [
            NOTICE line 2,
            NOTICE line 3,
          ],
        }
      }
      """

  Scenario: End of large file

    Given a file "logfile.log":
      """
      NOTICE line 0
      NOTICE line 1
      NOTICE line 2
      WARNING line 3
      NOTICE line 4
      """

    When I run log-monitor-client with config "default.config"

    Then the following events should be submitted:
      """
      {
        type: warning,
        source: { class: class, host: host, service: service },
        location: { file: logfile.log, line: 3 },
        lines: {
          before: [
            NOTICE line 1,
            NOTICE line 2,
          ],
          matching: WARNING line 3,
          after: [
            NOTICE line 4,
          ],
        }
      }
      """

  Scenario: Middle of short file

    Given a file "logfile.log":
      """
      NOTICE line 0
      WARNING line 1
      NOTICE line 2
      """

    When I run log-monitor-client with config "default.config"

    Then the following events should be submitted:
      """
      {
        type: warning,
        source: { class: class, host: host, service: service },
        location: { file: logfile.log, line: 1 },
        lines: {
          before: [
            NOTICE line 0,
          ],
          matching: WARNING line 1,
          after: [
            NOTICE line 2,
          ],
        }
      }
      """
